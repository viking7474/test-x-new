#!/usr/bin/env python3
"""Source wiring gate; --native additionally runs real Foundation lifecycle tests."""
from __future__ import annotations

import argparse
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def check(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def source_contracts() -> None:
    hook = (ROOT / "TLinkIOSTweak/DomainBlockingHooks.x").read_text(encoding="utf-8")
    helper = (ROOT / "TLinkIOSTweak/PXDomainTaskBlocker.m").read_text(encoding="utf-8")
    fixture = (ROOT / "tests/PXDomainTaskLifecycleTests.m").read_text(encoding="utf-8")
    session = hook.split("#pragma mark - NSURLSession Lifecycle Blocking", 1)[1].split(
        "#pragma mark - NSURLConnection Legacy Support", 1)[0]
    check(session.count("return PXDomainObservedSession(%orig);") == 3,
          "all three public session constructors must preserve original results")
    check("PXDomainObserveURLSession(session" in session and "shouldBlockDomain(host)" in session,
          "session observation must use live existing domain/scope policy")
    check(not any(token in session for token in
                  ("dispatch_after", "dispatch_get_global_queue", "[task cancel]", "127.0.0.1", "completionHandler(nil")),
          "session constructors must not fake a callback, cancel or redirect a task")
    check("%hook NSURLRequest" not in hook and "%hook NSMutableURLRequest" not in hook,
          "passive request construction must preserve the caller's real URL")
    check("if (!isScoped) return;" in hook and "PXHookCapabilityWebNetworking" in hook,
          "constructor scope/bootstrap gates must remain")
    check("Install hooks even when Domain Blocking is currently OFF" in hook,
          "feature must still support hot enable/disable")
    check("dispatch_after" not in helper and "127.0.0.1" not in helper and "NSURLProtocol" not in helper,
          "production task adapter must not emulate networking or rely on background-unsupported protocols")
    check("state != NSURLSessionTaskStateCompleted && state != NSURLSessionTaskStateCanceling" in helper and
          "[task cancel];" in helper and "policy.predicate(host)" in helper,
          "cancellation belongs to live policy at resume, not factory time")
    check("@finally" in helper and "gPXDomainResumingTask = previous;" in helper,
          "resume/super reentrancy guard must unwind even on exceptions")
    check("class_addMethod(cls, selector, replacement" in helper and
          "method_getArgumentType" in helper and "method_getReturnType" in helper and
          "method_getNumberOfArguments" in helper and '"@?"' in helper and "@encode(NSInteger)" in helper,
          "concrete-class interception must isolate inherited methods and validate full ABI")
    check("@property (atomic, assign) IMP original;" in helper and
          helper.index("hook.original = method_getImplementation(method)") < helper.index("imp_implementationWithBlock"),
          "a callable original must be published before the replacement")
    check("OBJC_ASSOCIATION_RETAIN_NONATOMIC" not in helper and
          "OBJC_ASSOCIATION_COPY_NONATOMIC" not in helper and
          helper.count("if (objc_getAssociatedObject(session, &kPXDomainSessionPredicate)) return YES;") == 2,
          "concurrent readers must retain published policies; observation must recheck under lock")
    for selector in (
        "dataTaskWithRequest:", "dataTaskWithURL:",
        "dataTaskWithRequest:completionHandler:", "dataTaskWithURL:completionHandler:",
        "uploadTaskWithRequest:fromData:", "uploadTaskWithRequest:fromData:completionHandler:",
        "uploadTaskWithRequest:fromFile:", "uploadTaskWithRequest:fromFile:completionHandler:",
        "uploadTaskWithStreamedRequest:", "downloadTaskWithRequest:", "downloadTaskWithURL:",
        "downloadTaskWithRequest:completionHandler:", "downloadTaskWithURL:completionHandler:",
        "downloadTaskWithResumeData:", "downloadTaskWithResumeData:completionHandler:",
        "webSocketTaskWithRequest:", "webSocketTaskWithURL:", "webSocketTaskWithURL:protocols:",
        "streamTaskWithHostName:port:",
    ):
        check(f'@"{selector}"' in helper, f"missing supported public factory: {selector}")
    check("NSURLErrorCancelled" in fixture and "gTransportStarts" in fixture and
          "suspended delegate queue is respected" in fixture and "ABI rejection preserves original" in fixture,
          "native fixtures must exercise lifecycle, transport, queue and ABI contracts")
    check(not re.search(r"\b(?:completionHandler|handler)\s*\(", helper),
          "the adapter must never directly invoke an application completion handler")
    print("PASS: Domain task lifecycle source contracts (native runtime not implied)")


def native_tests() -> None:
    check(sys.platform == "darwin", "--native requires macOS Foundation and xcrun; it must not silently skip")
    check(shutil.which("xcrun") is not None, "xcrun is required")
    with tempfile.TemporaryDirectory(prefix="px-domain-task-lifecycle-") as folder:
        binary = Path(folder) / "domain-task-lifecycle"
        subprocess.run([
            "xcrun", "clang", "-fobjc-arc", "-fblocks", "-Wall", "-Wextra",
            "-Werror=implicit-function-declaration", "-I", str(ROOT / "TLinkIOSTweak"),
            str(ROOT / "TLinkIOSTweak/PXDomainTaskBlocker.m"),
            str(ROOT / "tests/PXDomainTaskLifecycleTests.m"),
            "-framework", "Foundation", "-o", str(binary),
        ], cwd=ROOT, check=True, timeout=60)
        subprocess.run([str(binary)], cwd=ROOT, check=True, timeout=90)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--native", action="store_true")
    options = parser.parse_args()
    source_contracts()
    if options.native:
        native_tests()
