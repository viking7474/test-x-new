#!/usr/bin/env python3
"""T-0095 final iFake-vs-x-new parity/crosswalk regression gate.

This is an installer-aware audit. Some intentionally-unhooked libc/dyld APIs are
called internally by x-new, so raw symbol presence is not treated as coverage.
"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TWEAK_ROOT = ROOT / "TLinkIOSTweak"
REPORT = ROOT / "iFakePro_vs_x-new_Hook_Gap_Assessment.md"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def production_files() -> dict[str, str]:
    result: dict[str, str] = {}
    for suffix in ("*.x", "*.m", "*.mm", "*.c"):
        for path in sorted(TWEAK_ROOT.glob(suffix)):
            result[path.name] = path.read_text(encoding="utf-8", errors="replace")
    return result


FILES = production_files()
PRODUCTION = "\n".join(FILES.values())
REPORT_TEXT = REPORT.read_text(encoding="utf-8")

# Phase B closed exactly these 18 safe/query-oriented InitFunc_18 exact gaps.
PHASE_B_CLOSED = (
    "__opendir2", "fstat64", "fstatat64", "fstatfs64",
    "pathconf", "fpathconf", "getattrlist", "fgetattrlist",
    "getxattr", "fgetxattr", "listxattr", "flistxattr",
    "readdir_r", "getpeername", "getsockname", "issetugid", "getgroups",
    "CFNetworkCopyProxiesForAutoConfigurationScript",
)
for symbol in PHASE_B_CLOSED:
    require(symbol in PRODUCTION, f"final crosswalk lost covered Phase-B surface: {symbol}")

# 63 baseline non-Security gaps - 18 Phase-B closures = 45 intentional exact
# omissions. Ordinary calls/references do not count as hook installation.
REMAINING_45 = (
    "syscall", "read", "chdir", "chroot", "mkdir", "chmod", "chown", "getfh",
    "mknod", "unlinkat", "mkdirat", "renameat", "symlinkat", "linkat",
    "fchmodat", "fchownat", "pread", "pwrite", "fchmod", "fchown", "write",
    "fchdir", "execve", "freopen",
    "ioctl", "setxattr", "removexattr", "mmap", "mprotect", "fcntl", "strstr",
    "vm_region_64", "vm_region_recurse_64", "mach_vm_read_overwrite",
    "bootstrap_check_in", "sandbox_check", "xpc_connection_create_mach_service",
    "xpc_connection_create", "thread_get_state", "task_for_pid",
    "task_set_special_port", "_dyld_shared_cache_contains_path", "_dyld_image_count",
    "_dyld_get_image_vmaddr_slide", "_dyld_get_image_header",
)
require(len(REMAINING_45) == 45 and len(set(REMAINING_45)) == 45,
        "final remaining native-gap inventory must contain 45 unique symbols")


def has_installer(symbol: str) -> bool:
    escaped = re.escape(symbol)
    # Logos direct function hook.
    logos = re.compile(r"%hookf\([^,\n]+,\s*" + escaped + r"\s*,", re.S)
    # Explicitly named MSHookFunction adapters/original slots.
    named = re.compile(
        r"MSHookFunction\([^;]{0,420}(?<![A-Za-z0-9_])(?:hook_|orig_)?" + escaped + r"\b",
        re.S,
    )
    if any(logos.search(text) or named.search(text) for text in FILES.values()):
        return True

    # Many x-new installers use a generic local `sym`. Bind FindSymbol(name) only
    # to its local block up to the next FindSymbol; this deliberately permits the
    # fcntl F_GETPATH pointer capture because that block has no MSHookFunction.
    needles = (f'FindSymbol("{symbol}")', f'dlsym(RTLD_DEFAULT, "{symbol}")', f'dlsym(handle, "{symbol}")')
    for text in FILES.values():
        for needle in needles:
            start = 0
            while True:
                pos = text.find(needle, start)
                if pos < 0:
                    break
                boundaries = [
                    candidate for candidate in (
                        text.find("FindSymbol(", pos + len(needle)),
                        text.find("dlsym(", pos + len(needle)),
                    ) if candidate >= 0
                ]
                end = min(boundaries) if boundaries else min(len(text), pos + 1600)
                if "MSHookFunction" in text[pos:end]:
                    return True
                start = pos + len(needle)
    return False


for symbol in REMAINING_45:
    require(not has_installer(symbol),
            f"final intentional exact gap unexpectedly gained a production installer: {symbol}")

# C-02/C-03 are deliberate evidence-gated omissions, not raw implementation
# backlog. Keep the narrower owners and fixtures instead of global hooks.
EVIDENCE_GATED_ABSENT = (
    "CFPropertyListCreateWithData",
    "HTMLCanvasElement::toDataURL",
    "glReadPixels",
    "glGetString",
)
for symbol in EVIDENCE_GATED_ABSENT:
    require(symbol not in PRODUCTION,
            f"evidence-gated surface appeared in production without reclassification: {symbol}")

# C-04 also closed without exact private hooks. SBS is DIFFERENT/OPTIONAL because
# launch behavior is owned above the private C layer; NX remains evidence-gated
# absent until a concrete on-device bypass exists. All four must stay absent.
C04_PRIVATE_ABSENT = (
    "SBSLaunchApplicationWithIdentifierAndURLAndLaunchOptions",
    "SBSLaunchApplicationWithIdentifierAndLaunchOptions",
    "NXMapGet",
    "NXHashGet",
)
for symbol in C04_PRIVATE_ABSENT:
    require(symbol not in PRODUCTION,
            f"C-04 private symbol appeared in production without evidence reclassification: {symbol}")

# Security.framework falsification remains a raw source absence requirement.
BLOCKED_SECURITY = (
    "SecTaskCopyValueForEntitlement",
    "SecCodeCopySigningInformation",
    "SecStaticCodeCreateWithPath",
    "SecStaticCodeCheckValidity",
    "SecStaticCodeCheckValidityWithErrors",
)
for symbol in BLOCKED_SECURITY:
    require(symbol not in PRODUCTION, f"BLOCKED Security surface appeared: {symbol}")

# Pin the report arithmetic/classification so documentation cannot silently drift
# back to the pre-implementation 63-gap state.
for token in (
    "45 non-Security exact symbol gaps remain after Phase B",
    "Count = **24 + 7 + 14 = 45**",
    "EVIDENCE-GATED ABSENT / C-02 CLOSED",
    "EVIDENCE-GATED ABSENT / NOT NEEDED CURRENTLY",
    "C-04 CLOSED / EVIDENCE-GATED ABSENT",
    "SBS = higher-level DIFFERENT/OPTIONAL",
    "NX = EVIDENCE-GATED ABSENT",
    "Framework scalar COVERED",
    "Phase A — COMPLETE",
    "Phase B — COMPLETE for the approved safe surface",
    "Phase C — COMPLETE for current evidence",
):
    require(token in REPORT_TEXT, f"final gap assessment drifted: {token}")

print("iFake final crosswalk static gate: PASS")
print(f"covered_phase_b={len(PHASE_B_CLOSED)} remaining_exact={len(REMAINING_45)} blocked_security={len(BLOCKED_SECURITY)} evidence_gated={len(EVIDENCE_GATED_ABSENT)} c04_absent={len(C04_PRIVATE_ABSENT)}")
