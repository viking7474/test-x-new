#!/usr/bin/env python3
"""Source and semantic matrix for JailbreakBypassHooks Patch D."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE_PATH = ROOT / "ProjectXTweak" / "JailbreakBypassHooks.x"
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
            print(f"cleanup lifecycle matrix: FAIL ({self.failed}/{self.total})")
            raise SystemExit(1)
        print(f"cleanup lifecycle matrix: PASS ({self.total}/{self.total})")


def source_function(name: str) -> str:
    match = re.search(
        rf"(?ms)^static[ \t]+[^\n;{{]+?\b{re.escape(name)}\s*\([^;{{]*?\)\s*\{{",
        SOURCE,
    )
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


def logos_hook_block(class_name: str) -> str:
    marker = f"%hook {class_name}"
    start = SOURCE.index(marker)
    end = SOURCE.index("%end", start) + len("%end")
    return SOURCE[start:end]


def logos_method_body(block: str, selector: str) -> str:
    signature = re.search(
        rf"(?m)^[-+] \([^\n]+\){re.escape(selector)}[^\n]*\{{",
        block,
    )
    if not signature:
        raise RuntimeError(f"missing Logos method: {selector}")
    brace = block.index("{", signature.start())
    depth = 0
    for index in range(brace, len(block)):
        if block[index] == "{":
            depth += 1
        elif block[index] == "}":
            depth -= 1
            if depth == 0:
                return block[signature.start() : index + 1]
    raise RuntimeError(f"unterminated Logos method: {selector}")


def private_preboot_hidden(value: str) -> bool:
    lower = value.lower()
    prefix = "/private/preboot"
    if not lower.startswith(prefix):
        return False
    if len(value) > len(prefix) and value[len(prefix)] != "/":
        return False
    descendants = [part.lower() for part in value[len(prefix):].split("/") if part]
    return any(
        part in {"jb", "procursus", "dopamine", "palera1n"} or part.startswith("jb-")
        for part in descendants
    )


def shell_hidden(value: str | None) -> bool:
    if not value:
        return False
    lower = value.lower()
    if lower in {"/bin/bash", "/bin/zsh", "/usr/bin/bash", "/usr/bin/zsh"}:
        return True
    if lower.startswith("/var/jb/") or lower.startswith("/private/var/jb/"):
        return True
    return private_preboot_hidden(value)


def run_workspace_matrix(matrix: Matrix) -> None:
    matrix.check(
        "workspace: exactly one Logos hook",
        len(re.findall(r"(?m)^%hook LSApplicationWorkspace$", SOURCE)) == 1,
    )
    block = logos_hook_block("LSApplicationWorkspace")
    selectors = {
        "allInstalledApplications": "PXJBFilterWorkspaceApplications",
        "installedApplications": "PXJBFilterWorkspaceApplications",
        "allApplications": "PXJBFilterWorkspaceApplications",
        "installedPlugins": "PXJBFilterWorkspacePlugins",
    }
    for selector, helper in selectors.items():
        body = logos_method_body(block, selector)
        matrix.check(f"workspace: {selector} calls own %orig", "%orig" in body)
        matrix.check(f"workspace: {selector} uses shared filter", helper in body)
    matrix.check(
        "workspace: no installedApplications alias",
        "return [self allInstalledApplications]" not in SOURCE,
    )
    matrix.check(
        "workspace: application filter preserves original when unchanged",
        "return changed ? [filtered copy] : applications;"
        in source_function("PXJBFilterWorkspaceApplications"),
    )
    matrix.check(
        "workspace: plugin filter preserves original when unchanged",
        "return changed ? [filtered copy] : plugins;"
        in source_function("PXJBFilterWorkspacePlugins"),
    )


def run_shell_matrix(matrix: Matrix) -> None:
    fixtures = [
        ("stock sh remains visible", "/bin/sh", False),
        ("ordinary fish remains visible", "/usr/bin/fish", False),
        ("app-local shell remains visible", "/Applications/Test.app/bin/shell", False),
        ("bash hidden", "/bin/bash", True),
        ("zsh hidden", "/bin/zsh", True),
        ("rootless shell hidden", "/var/jb/usr/bin/bash", True),
        ("private rootless shell hidden", "/private/var/jb/bin/sh", True),
        ("preboot bootstrap shell hidden", "/private/preboot/UUID/jb-123/procursus/bin/bash", True),
        ("normal preboot shell visible", "/private/preboot/UUID/Cryptexes/OS/bin/sh", False),
    ]
    for name, value, expected in fixtures:
        matrix.check(f"shell: {name}", shell_hidden(value) is expected)

    getenv_body = source_function("hook_getenv")
    always_body = source_function("PXJBEnvironmentKeyAlwaysHidden")
    cleanup_body = source_function("PXJBUnsetSuspiciousEnvIfNeeded")
    environment_block = logos_hook_block("NSProcessInfo")
    environment_body = logos_method_body(environment_block, "environment")
    matrix.check("shell: SHELL is not always-hidden key", '"SHELL"' not in always_body)
    matrix.check("shell: getenv reads original value first", "char *value = orig_getenv" in getenv_body)
    matrix.check("shell: getenv applies conditional helper", "PXJBShellEnvironmentValueShouldHide(value)" in getenv_body)
    matrix.check("shell: raw cleanup reads original SHELL", 'orig_getenv("SHELL")' in cleanup_body)
    matrix.check("shell: raw cleanup conditionally unsets SHELL", "PXJBShellEnvironmentValueShouldHide(shell)" in cleanup_body and 'unsetenv("SHELL")' in cleanup_body)
    matrix.check("shell: NSProcessInfo conditionally removes SHELL", 'out[@"SHELL"]' in environment_body and "PXJBShellEnvironmentValueShouldHide" in environment_body)


def run_xpc_matrix(matrix: Matrix) -> None:
    matrix.check(
        "xpc: dictionary symbol declared as object",
        "extern const struct _xpc_type_s _xpc_type_dictionary;" in SOURCE,
    )
    matrix.check(
        "xpc: macro takes address with xpc_type_t cast",
        "#define XPC_TYPE_DICTIONARY ((xpc_type_t)&_xpc_type_dictionary)" in SOURCE,
    )
    matrix.check(
        "xpc: old pointer-object declaration removed",
        "extern xpc_type_t _xpc_type_dictionary;" not in SOURCE,
    )


def run_findsymbol_matrix(matrix: Matrix) -> None:
    body = source_function("FindSymbol")
    matrix.check("findsymbol: one-argument definition", "FindSymbol(const char *symbol)" in body)
    matrix.check("findsymbol: direct RTLD_DEFAULT lookup", "dlsym(RTLD_DEFAULT, symbol)" in body)
    matrix.check("findsymbol: no dlopen", "dlopen" not in body)
    matrix.check("findsymbol: no image parameter", "image" not in body)
    matrix.check("findsymbol: no legacy NULL call sites", "FindSymbol(NULL," not in SOURCE)
    matrix.check(
        "findsymbol: all call sites are one argument",
        not re.search(r"FindSymbol\([^\n()]*,", SOURCE),
    )


def run_late_load_matrix(matrix: Matrix) -> None:
    rules = re.findall(
        r'PXJB_DETECTION_RULE\("([^"]+)", "([^"]+)", (true|false), (kPXJBDetectionReturn\w+)\)',
        SOURCE,
    )
    matrix.check("late-load: expected rule count", len(rules) == 31)
    matrix.check("late-load: rules are unique", len(rules) == len(set(rules)))
    expected = {
        ("UIDevice", "isJailbroken", "true", "kPXJBDetectionReturnFalse"),
        ("DTTJailbreakDetection", "isJailbroken", "true", "kPXJBDetectionReturnFalse"),
        ("UBReportMetadataDevice", "is_rooted", "false", "kPXJBDetectionReturnNull"),
        ("EnrollParameters", "jailbroken", "false", "kPXJBDetectionReturnNull"),
        ("AWMyDeviceGeneralInfo", "isCompliant", "false", "kPXJBDetectionReturnTrue"),
    }
    matrix.check("late-load: representative policies preserved", expected <= set(rules))

    detector_classes = {rule[0] for rule in rules}
    old_logos = set(
        re.findall(r"(?m)^%hook ([A-Za-z_][A-Za-z0-9_]*)$", SOURCE)
    ) & detector_classes
    matrix.check("late-load: detector Logos hooks removed", not old_logos)

    installer = source_function("PXJBInstallLoadedDetectionClassHooks")
    callback = source_function("PXJBLateDetectionImageAdded")
    start = source_function("PXJBStartLateLoadedDetectionClassMonitoring")
    register = source_function("PXJBRegisterDyldAddImageCallback")
    matrix.check("late-load: installer resolves classes dynamically", "objc_getClass(rule->className)" in installer)
    matrix.check("late-load: installer checks selector availability", "class_getInstanceMethod" in installer)
    matrix.check("late-load: installer hooks with MSHookMessageEx", "MSHookMessageEx" in installer)
    matrix.check("late-load: installer detects category replacement", "method_getImplementation(method) == rule->replacement" in installer)
    matrix.check("late-load: callback only enqueues work", "dispatch_async" in callback and "MSHookMessageEx" not in callback and "objc_getClass" not in callback)
    matrix.check("late-load: callback coalesces image bursts", "atomic_exchange_explicit" in callback)
    matrix.check("late-load: monitor registers dyld callback", "PXJBRegisterDyldAddImageCallback" in start)
    matrix.check("late-load: internal callback bypasses public blocker", "orig__dyld_register_func_for_add_image(callback)" in register)
    matrix.check("late-load: monitoring starts after policy publication", SOURCE.index("PXJBPublishPolicySnapshot(launchSettings);", SOURCE.index("PXJBFinalizeCapabilityRegistryAndAudit")) < SOURCE.index("PXJBStartLateLoadedDetectionClassMonitoring();"))


def main() -> None:
    matrix = Matrix()
    run_workspace_matrix(matrix)
    run_shell_matrix(matrix)
    run_xpc_matrix(matrix)
    run_findsymbol_matrix(matrix)
    run_late_load_matrix(matrix)
    matrix.finish()


if __name__ == "__main__":
    main()
