#!/usr/bin/env python3
"""P2 source and semantic matrix for JailbreakBypassHooks.x."""

from __future__ import annotations

import random
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

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
            print(f"jailbreak bypass P2 matrix: FAIL ({self.failed}/{self.total})")
            raise SystemExit(1)
        print(f"jailbreak bypass P2 matrix: PASS ({self.total}/{self.total})")


def extract_rule_array(name: str) -> list[str]:
    pattern = re.compile(
        rf"static const PXJBStaticPathRule {re.escape(name)}\[\] = \{{(.*?)\n\}};",
        re.S,
    )
    match = pattern.search(SOURCE)
    if not match:
        raise RuntimeError(f"missing rule array: {name}")
    return re.findall(r'PXJB_PATH_RULE\("((?:\\.|[^"\\])*)"\)', match.group(1))


EXACT = extract_rule_array("kPXJBHiddenExactRules")
PREFIX = extract_rule_array("kPXJBHiddenPrefixRules")


def linear_match(path: str) -> bool:
    return path in EXACT or any(path.startswith(prefix) for prefix in PREFIX)


class TrieNode:
    __slots__ = ("children", "exact", "prefix")

    def __init__(self) -> None:
        self.children: dict[str, TrieNode] = {}
        self.exact = False
        self.prefix = False


TRIE_ROOT = TrieNode()
for rule in EXACT:
    node = TRIE_ROOT
    for byte in rule:
        node = node.children.setdefault(byte, TrieNode())
    node.exact = True
for rule in PREFIX:
    node = TRIE_ROOT
    for byte in rule:
        node = node.children.setdefault(byte, TrieNode())
    node.prefix = True


def trie_match(path: str) -> bool:
    node = TRIE_ROOT
    for byte in path:
        node = node.children.get(byte)
        if node is None:
            return False
        if node.prefix:
            return True
    return node.exact or node.prefix


HIGH_CONFIDENCE = {"cydia.app", "sileo.app", "zebra.app", "filza.app"}


def entry_hidden(parent: str | None, name: str) -> bool:
    if name in {"", ".", ".."}:
        return False
    if parent is None:
        return name.lower() in HIGH_CONFIDENCE
    child = f"/{name}" if parent == "/" else f"{parent}/{name}"
    if trie_match(child):
        return True
    return parent in {"/Applications", "/var/jb/Applications"} and name.lower() in HIGH_CONFIDENCE


@dataclass
class Record:
    stream: int
    generation: int
    parent: str


class DirectoryRegistryModel:
    def __init__(self) -> None:
        self.records: dict[int, Record] = {}
        self.generation = 1

    def register(self, stream: int, parent: str) -> Record:
        record = Record(stream, self.generation, parent)
        self.generation += 1
        self.records[stream] = record
        return record

    def detach(self, stream: int) -> Record | None:
        return self.records.pop(stream, None)

    def restore(self, record: Record | None) -> bool:
        if record is None or record.stream in self.records:
            return False
        self.records[record.stream] = record
        return True

    def path(self, stream: int) -> str | None:
        record = self.records.get(stream)
        return record.parent if record else None


def visible_entries(
    parent: str | None,
    entries: Iterable[str],
    filtering: bool = True,
) -> list[str]:
    if not filtering:
        return list(entries)
    return [name for name in entries if not entry_hidden(parent, name)]


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


def run_source_matrix(matrix: Matrix) -> None:
    installed = set(
        re.findall(
            r"MSHookFunction\([^;]*?\(void \*\*\)&(orig_[A-Za-z0-9_]+)\)",
            SOURCE,
            re.S,
        )
    )
    audited = set(
        re.findall(
            r'PXJB_AUDIT\([^,]+,\s*"[^"]+",\s*(orig_[A-Za-z0-9_]+)',
            SOURCE,
        )
    )
    install_group = SOURCE[
        SOURCE.index("// P2: install opendir/readdir/closedir as one lifecycle group.") :
        SOURCE.index('sym = FindSymbol("readlink")')
    ]
    closedir_body = source_function("hook_closedir")
    opendir_body = source_function("hook_opendir")
    fdopendir_body = source_function("hook_fdopendir")
    readdir_body = source_function("hook_readdir")
    register_body = source_function("PXJBRegisterDirectoryStream")

    matrix.check("source: exact rule count is stable", len(EXACT) == 92)
    matrix.check("source: prefix rule count is stable", len(PREFIX) == 46)
    matrix.check("source: optimized trie initialized once", "pthread_once(&gJBPathMatcherOnce" in SOURCE)
    matrix.check("source: matcher has linear fallback", "PXJBPathMatchesHiddenRulesLinear(path)" in SOURCE)
    matrix.check("source: matcher readiness is audited", '"path-matcher-optimized"' in SOURCE)
    matrix.check("source: lifecycle resolves all mandatory entries before install", all(
        install_group.index(token) < install_group.index("MSHookFunction(opendirEntry")
        for token in [
            'FindSymbol("opendir")',
            'FindSymbol("readdir")',
            'FindSymbol("closedir")',
        ]
    ))
    matrix.check("source: lifecycle installs closedir", "MSHookFunction(closedirEntry" in install_group)
    matrix.check("source: fdopendir is optional", "if (fdopendirEntry)" in install_group)
    matrix.check("source: lifecycle readiness uses release publication", "memory_order_release" in install_group)
    matrix.check("source: closedir detaches before original", closedir_body.index("PXJBDetachDirectoryStream") < closedir_body.index("PXJBOriginalClosedir"))
    matrix.check("source: failed closedir restores context", "PXJBRestoreDirectoryStream(detached)" in closedir_body)
    matrix.check("source: successful closedir frees context", "result == 0" in closedir_body and "PXJBFreeDirectoryStreamRecord(detached)" in closedir_body)
    matrix.check("source: opendir preserves errno around registration", "int savedErrno = errno;" in opendir_body and "errno = savedErrno;" in opendir_body)
    matrix.check("source: fdopendir preserves errno around registration", "int savedErrno = errno;" in fdopendir_body and "errno = savedErrno;" in fdopendir_body)
    matrix.check("source: fdopendir rejects hidden path before ownership transfer", fdopendir_body.index("PXJBPathMatchesHiddenRules") < fdopendir_body.index("PXJBOriginalFdopendir"))
    matrix.check("source: readdir classifies full child path", "PXJBDirectoryEntryShouldHide" in readdir_body)
    matrix.check("source: readdir leaves EOF errno to original", "errno =" not in readdir_body)
    matrix.check("source: registry replacement is one critical section", register_body.count("pthread_mutex_lock") == 1 and "PXJBDetachDirectoryStream(stream)" not in register_body)
    matrix.check("source: lifecycle capability is required", '"directory-stream-lifecycle"' in SOURCE)
    matrix.check("source: all installed trampolines audited", not (installed - audited))
    matrix.check("source: expected installed trampoline count", len(installed) == 67)


def run_matcher_matrix(matrix: Matrix) -> None:
    matrix.check("matcher: exact rules are unique", len(EXACT) == len(set(EXACT)))
    matrix.check("matcher: prefix rules are unique", len(PREFIX) == len(set(PREFIX)))
    matrix.check("matcher: every exact rule matches trie", all(trie_match(rule) for rule in EXACT))
    matrix.check("matcher: every exact rule matches fallback", all(linear_match(rule) for rule in EXACT))
    matrix.check("matcher: every prefix matches itself", all(trie_match(rule) for rule in PREFIX))
    matrix.check("matcher: every prefix matches descendants", all(trie_match(rule + "child") for rule in PREFIX))

    normal_paths = [
        "/Applications/MyBank.app",
        "/var/mobile/Containers/Data/Application/ABC/Documents/file.txt",
        "/System/Library/Frameworks/UIKit.framework/UIKit",
        "/tmp/Cydia.app",
        "/private/var/mobile/Library/Preferences/app.plist",
        "/usr/lib/libobjc.A.dylib",
    ]
    matrix.check("matcher: normal path corpus remains visible", not any(trie_match(path) for path in normal_paths))
    matrix.check("matcher: matching remains case-sensitive", not trie_match("/applications/Cydia.app"))
    matrix.check("matcher: exact suffix does not match", not trie_match("/Applications/Cydia.app.backup"))
    matrix.check("matcher: relative paths do not match", not trie_match("Applications/Cydia.app"))

    rng = random.Random(0x5032)
    corpus = list(EXACT)
    corpus.extend(PREFIX)
    corpus.extend(prefix + "child/grandchild" for prefix in PREFIX)
    corpus.extend(normal_paths)
    alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/_-."
    for _ in range(500):
        length = rng.randint(1, 96)
        corpus.append("/" + "".join(rng.choice(alphabet) for _ in range(length)))
    matrix.check("matcher: trie and fallback are equivalent", all(trie_match(path) == linear_match(path) for path in corpus))


def run_lifecycle_matrix(matrix: Matrix) -> None:
    registry = DirectoryRegistryModel()
    first = registry.register(0x1000, "/Applications")
    matrix.check("lifecycle: opendir context registered", registry.path(0x1000) == "/Applications")
    matrix.check("lifecycle: Cydia hidden under Applications", entry_hidden(registry.path(0x1000), "Cydia.app"))
    matrix.check("lifecycle: app-name compatibility is case-insensitive", entry_hidden(registry.path(0x1000), "cYdIa.ApP"))
    matrix.check("lifecycle: ordinary app visible under Applications", not entry_hidden(registry.path(0x1000), "MyBank.app"))
    matrix.check("lifecycle: same basename visible in unrelated tracked parent", not entry_hidden("/tmp", "Cydia.app"))
    matrix.check("lifecycle: dot entries always visible", not entry_hidden("/Applications", ".") and not entry_hidden("/Applications", ".."))
    matrix.check("lifecycle: untracked fallback retains high-confidence names", entry_hidden(None, "cYdIa.ApP"))
    matrix.check("lifecycle: untracked normal entry remains visible", not entry_hidden(None, "MyBank.app"))
    matrix.check("lifecycle: untracked fallback stays narrow", not entry_hidden(None, "Dopamine.app"))

    detached = registry.detach(0x1000)
    matrix.check("lifecycle: close detaches context", detached == first and registry.path(0x1000) is None)
    matrix.check("lifecycle: failed close restores context", registry.restore(detached) and registry.path(0x1000) == "/Applications")

    detached_again = registry.detach(0x1000)
    matrix.check("lifecycle: successful close leaves no record", detached_again is not None and registry.path(0x1000) is None)

    old = registry.register(0x2000, "/Applications")
    detached_old = registry.detach(0x2000)
    new = registry.register(0x2000, "/tmp")
    matrix.check("lifecycle: reused DIR pointer gets new generation", new.generation > old.generation)
    matrix.check("lifecycle: old successful close cannot remove reused pointer", registry.path(0x2000) == "/tmp")
    matrix.check("lifecycle: old failed close cannot overwrite reused pointer", not registry.restore(detached_old) and registry.path(0x2000) == "/tmp")

    entries = [".", "..", "Cydia.app", "MyBank.app", "Sileo.app"]
    matrix.check("lifecycle: readdir skips hidden sequence", visible_entries("/Applications", entries) == [".", "..", "MyBank.app"])
    matrix.check("lifecycle: policy off is exact pass-through", visible_entries("/Applications", entries, filtering=False) == entries)
    matrix.check("lifecycle: root child path joins correctly", entry_hidden("/", "var" ) is False and entry_hidden("/", ".installed_unc0ver"))


def main() -> None:
    matrix = Matrix()
    run_source_matrix(matrix)
    run_matcher_matrix(matrix)
    run_lifecycle_matrix(matrix)
    matrix.finish()


if __name__ == "__main__":
    main()
