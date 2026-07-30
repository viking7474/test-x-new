#!/usr/bin/env python3
"""Static Backup/Restore hardening audit.

Python 3.9+, standard library only. This file is intentionally invoked through
``python3`` and therefore does not require an executable bit.
"""
from __future__ import annotations

from collections import Counter, defaultdict
from dataclasses import dataclass
from pathlib import Path
import re
import sys
from typing import Dict, Iterable, List, Mapping, Optional, Sequence, Tuple

MINIMUM_REPOSITORY_GUARDS = 450
MINIMUM_SELF_TESTS = 42
DEBUG_TRACEBACK = False


class AuditInternalError(Exception):
    """Deterministic parser/reader/internal failure."""


@dataclass(frozen=True)
class Literal:
    kind: str
    value: str
    start: int
    end: int
    line: int


@dataclass(frozen=True)
class SourceFile:
    path: str
    data: bytes
    text: str
    masked: str
    literals: Tuple[Literal, ...]


@dataclass(frozen=True)
class MethodRecord:
    kind: str
    selector: str
    return_type: str
    argument_names: Tuple[str, ...]
    signature_start_line: int
    signature_start: int
    signature_end: int
    body_start: Optional[int]
    body_end: Optional[int]
    body_text: str
    sanitized_body_text: str
    is_definition: bool


def line_number(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def decode_escape(text: str, index: int) -> Tuple[str, int]:
    if index + 1 >= len(text):
        raise AuditInternalError("unterminated escape sequence")
    nxt = text[index + 1]
    simple = {"n": "\n", "r": "\r", "t": "\t", "\\": "\\", '"': '"', "'": "'", "0": "\0"}
    return simple.get(nxt, nxt), index + 2


def mask_source(text: str) -> Tuple[str, Tuple[Literal, ...]]:
    """Mask comments and literals while preserving length/newline offsets."""
    chars = list(text)
    literals: List[Literal] = []
    index = 0
    length = len(text)

    def blank(start: int, end: int) -> None:
        for pos in range(start, end):
            if chars[pos] not in ("\r", "\n"):
                chars[pos] = " "

    while index < length:
        if text.startswith("//", index):
            start = index
            end = text.find("\n", index + 2)
            if end < 0:
                end = length
            blank(start, end)
            index = end
            continue
        if text.startswith("/*", index):
            start = index
            end_marker = text.find("*/", index + 2)
            if end_marker < 0:
                raise AuditInternalError(f"unterminated block comment at line {line_number(text, start)}")
            end = end_marker + 2
            blank(start, end)
            index = end
            continue

        objc = text.startswith('@"', index)
        if objc or text[index] == '"':
            start = index
            quote = index + 1 if objc else index
            cursor = quote + 1
            value: List[str] = []
            while cursor < length:
                char = text[cursor]
                if char == "\\":
                    decoded, cursor = decode_escape(text, cursor)
                    value.append(decoded)
                    continue
                if char == '"':
                    end = cursor + 1
                    literals.append(Literal("objc-string" if objc else "c-string", "".join(value), start, end, line_number(text, start)))
                    blank(start, end)
                    index = end
                    break
                if char in ("\r", "\n"):
                    raise AuditInternalError(f"unterminated string literal at line {line_number(text, start)}")
                value.append(char)
                cursor += 1
            else:
                raise AuditInternalError(f"unterminated string literal at line {line_number(text, start)}")
            continue

        if text[index] == "'":
            start = index
            cursor = index + 1
            value: List[str] = []
            while cursor < length:
                char = text[cursor]
                if char == "\\":
                    decoded, cursor = decode_escape(text, cursor)
                    value.append(decoded)
                    continue
                if char == "'":
                    end = cursor + 1
                    literals.append(Literal("character", "".join(value), start, end, line_number(text, start)))
                    blank(start, end)
                    index = end
                    break
                if char in ("\r", "\n"):
                    raise AuditInternalError(f"unterminated character literal at line {line_number(text, start)}")
                value.append(char)
                cursor += 1
            else:
                raise AuditInternalError(f"unterminated character literal at line {line_number(text, start)}")
            continue
        index += 1

    masked = "".join(chars)
    if len(masked) != len(text):
        raise AuditInternalError("lexical masker changed source length")
    if [i for i, c in enumerate(masked) if c == "\n"] != [i for i, c in enumerate(text) if c == "\n"]:
        raise AuditInternalError("lexical masker changed newline offsets")
    return masked, tuple(literals)


def read_source(root: Path, relative_path: str) -> SourceFile:
    path = root / relative_path
    if not path.exists():
        raise AuditInternalError(f"missing required file: {relative_path}")
    if not path.is_file():
        raise AuditInternalError(f"required path is not a file: {relative_path}")
    data = path.read_bytes()
    if b"\x00" in data:
        raise AuditInternalError(f"NUL byte in required file: {relative_path}")
    try:
        text = data.decode("utf-8", errors="strict")
    except UnicodeDecodeError as exc:
        raise AuditInternalError(f"UTF-8 decode failed for {relative_path} at byte {exc.start}") from None
    for marker in ("<<<<<<<", "=======", ">>>>>>>"):
        if marker in text:
            raise AuditInternalError(f"conflict marker in required file: {relative_path}")
    if Path(relative_path).suffix in {".h", ".m", ".mm", ".xm", ".x", ".c", ".cc", ".cpp"}:
        masked, literals = mask_source(text)
    else:
        masked, literals = text, tuple()
    return SourceFile(relative_path, data, text, masked, literals)


def matching_delimiter(masked: str, start: int, opener: str, closer: str) -> int:
    if start >= len(masked) or masked[start] != opener:
        raise AuditInternalError(f"expected {opener!r} at offset {start}")
    depth = 0
    for index in range(start, len(masked)):
        char = masked[index]
        if char == opener:
            depth += 1
        elif char == closer:
            depth -= 1
            if depth == 0:
                return index
            if depth < 0:
                break
    raise AuditInternalError(f"unbalanced {opener}{closer} beginning at line {line_number(masked, start)}")


def selector_from_signature(signature: str) -> Tuple[str, str, Tuple[str, ...]]:
    kind_match = re.match(r"\s*([+-])\s*\(", signature)
    if not kind_match:
        raise AuditInternalError("invalid Objective-C method signature")
    open_paren = signature.find("(", kind_match.start())
    close_paren = matching_delimiter(signature, open_paren, "(", ")")
    return_type = " ".join(signature[open_paren + 1:close_paren].split())
    tail = signature[close_paren + 1:]
    pieces = re.findall(r"\b([A-Za-z_]\w*)\s*:", tail)
    if pieces:
        selector = ":".join(pieces) + ":"
        argument_names: List[str] = []
        for match in re.finditer(r"\b[A-Za-z_]\w*\s*:\s*\([^)]*\)\s*([A-Za-z_]\w*)", tail, re.S):
            argument_names.append(match.group(1))
        return selector, return_type, tuple(argument_names)
    name_match = re.search(r"\b([A-Za-z_]\w*)\s*$", tail)
    if not name_match:
        raise AuditInternalError("unable to parse Objective-C selector")
    return name_match.group(1), return_type, tuple()


def parse_objc_methods(text: str, masked: Optional[str] = None) -> Tuple[MethodRecord, ...]:
    if masked is None:
        masked, _ = mask_source(text)
    records: List[MethodRecord] = []
    method_start = re.compile(r"(?m)^[ \t]*([+-])\s*\(")
    cursor = 0
    while True:
        match = method_start.search(masked, cursor)
        if not match:
            break
        start = match.start()
        scan = match.end()
        paren = 1
        bracket = 0
        delimiter = None
        while scan < len(masked):
            char = masked[scan]
            if char == "(":
                paren += 1
            elif char == ")":
                paren -= 1
            elif char == "[":
                bracket += 1
            elif char == "]":
                bracket -= 1
            elif char in (";", "{") and paren == 0 and bracket == 0:
                delimiter = scan
                break
            scan += 1
        if delimiter is None:
            raise AuditInternalError(f"unterminated Objective-C signature at line {line_number(text, start)}")
        signature = text[start:delimiter]
        selector, return_type, argument_names = selector_from_signature(signature)
        if masked[delimiter] == ";":
            records.append(MethodRecord(match.group(1), selector, return_type, argument_names,
                                        line_number(text, start), start, delimiter + 1,
                                        None, None, "", "", False))
            cursor = delimiter + 1
            continue
        body_end = matching_delimiter(masked, delimiter, "{", "}")
        records.append(MethodRecord(match.group(1), selector, return_type, argument_names,
                                    line_number(text, start), start, delimiter,
                                    delimiter, body_end + 1,
                                    text[delimiter:body_end + 1], masked[delimiter:body_end + 1], True))
        cursor = body_end + 1
    return tuple(records)


def unique_method(methods: Sequence[MethodRecord], selector: str, definition: bool = True) -> MethodRecord:
    matches = [method for method in methods if method.selector == selector and method.is_definition == definition]
    if len(matches) != 1:
        raise AuditInternalError(f"expected exactly one {'definition' if definition else 'declaration'} for {selector}; found {len(matches)}")
    return matches[0]


def extract_anonymous_extension(source: SourceFile, class_name: str) -> Tuple[int, int, str, str]:
    pattern = re.compile(r"@interface\s+" + re.escape(class_name) + r"\s*\(\s*\)")
    match = pattern.search(source.masked)
    if not match:
        raise AuditInternalError(f"missing anonymous extension for {class_name}")
    end_match = re.search(r"(?m)^\s*@end\b", source.masked[match.end():])
    if not end_match:
        raise AuditInternalError(f"unterminated anonymous extension for {class_name}")
    end_start = match.end() + end_match.start()
    end = match.end() + end_match.end()
    return match.start(), end, source.text[match.start():end], source.masked[match.start():end]


def extract_self_message_selectors(body_masked: str) -> Tuple[str, ...]:
    selectors: List[str] = []
    for match in re.finditer(r"\[\s*self\s+", body_masked):
        start = match.start()
        end = matching_delimiter(body_masked, start, "[", "]")
        content = body_masked[match.end():end]
        pieces = re.findall(r"\b([A-Za-z_]\w*)\s*:", content)
        if pieces:
            selectors.append(":".join(pieces) + ":")
        else:
            name = re.match(r"\s*([A-Za-z_]\w*)", content)
            if name:
                selectors.append(name.group(1))
    return tuple(selectors)


def assert_test(condition: bool, message: str) -> None:
    if not condition:
        raise AuditInternalError(message)


def run_parser_self_tests() -> Tuple[int, int]:
    tests: List[Tuple[str, callable]] = []

    def add(name: str, fn: callable) -> None:
        tests.append((name, fn))

    add("line-comment-mask", lambda: assert_test(mask_source("a//x\nb")[0] == "a   \nb", "line comment"))
    add("block-comment-mask", lambda: assert_test(mask_source("a/*x*/b")[0] == "a     b", "block comment"))
    add("objc-string-mask", lambda: assert_test(mask_source('@"x"')[1][0].kind == "objc-string", "objc string"))
    add("c-string-mask", lambda: assert_test(mask_source('"x"')[1][0].kind == "c-string", "c string"))
    add("character-mask", lambda: assert_test(mask_source("'x'")[1][0].kind == "character", "character"))
    add("escaped-quote", lambda: assert_test(mask_source('"a\\\"b"')[1][0].value == 'a"b', "escaped quote"))
    add("escaped-backslash", lambda: assert_test(mask_source('"a\\\\b"')[1][0].value == "a\\b", "escaped slash"))
    add("length-preserved", lambda: assert_test(len(mask_source('a/*b*/@"c"')[0]) == len('a/*b*/@"c"'), "length"))
    add("newline-preserved", lambda: assert_test(mask_source("/*a\nb*/")[0].count("\n") == 1, "newline"))
    add("unterminated-comment", lambda: expect_internal(lambda: mask_source("/*")))
    add("unterminated-string", lambda: expect_internal(lambda: mask_source('"x')))
    add("unterminated-character", lambda: expect_internal(lambda: mask_source("'x")))
    add("multiline-declaration", lambda: assert_test(parse_objc_methods("- (void)one:(id)x\n two:(id)y;\n")[0].selector == "one:two:", "multiline declaration"))
    add("multiline-definition", lambda: assert_test(parse_objc_methods("- (void)one:(id)x\n two:(id)y {\n}\n")[0].is_definition, "multiline definition"))
    add("one-line-definition", lambda: assert_test(parse_objc_methods("- (void)go { int x = 0; }\n")[0].selector == "go", "one line"))
    add("nested-c-braces", lambda: assert_test(parse_objc_methods("- (void)go { if (1) { while (0) {} } }\n")[0].body_text.count("{") == 3, "nested braces"))
    add("objc-block-braces", lambda: assert_test(parse_objc_methods("- (void)go { void (^b)(void) = ^{ if (1) {} }; }\n")[0].is_definition, "block braces"))
    add("dictionary-literal-braces", lambda: assert_test(parse_objc_methods('- (void)go { id x = @{ @"a": @{ @"b": @1 } }; }\n')[0].is_definition, "dictionary"))
    add("comment-braces", lambda: assert_test(parse_objc_methods("- (void)go { /* }}} */ int x; }\n")[0].is_definition, "comment braces"))
    add("string-braces", lambda: assert_test(parse_objc_methods('- (void)go { id x = @"}}}"; }\n')[0].is_definition, "string braces"))
    add("declaration-definition", lambda: assert_test([m.is_definition for m in parse_objc_methods("- (void)a;\n- (void)b {}\n")] == [False, True], "declaration distinction"))
    add("duplicate-detection", lambda: expect_internal(lambda: unique_method(parse_objc_methods("- (void)a {}\n- (void)a {}\n"), "a")))
    add("class-extension", lambda: extension_test())
    add("message-selector", lambda: assert_test(extract_self_message_selectors("{ [self one:x two:y]; }") == ("one:two:",), "message selector"))
    add("unbalanced-body", lambda: expect_internal(lambda: parse_objc_methods("- (void)a { if (1) { }\n")))

    passed = 0
    for name, test in tests:
        try:
            test()
        except Exception as exc:
            raise AuditInternalError(f"self-test {name} failed: {exc}") from None
        passed += 1
    return passed, len(tests)


def expect_internal(fn: callable) -> None:
    try:
        fn()
    except AuditInternalError:
        return
    raise AuditInternalError("expected parser failure")


def extension_test() -> None:
    text = "@interface A ()\n- (void)x;\n@end\n@implementation A\n@end\n"
    masked, literals = mask_source(text)
    source = SourceFile("memory.m", text.encode(), text, masked, literals)
    _, _, extension, _ = extract_anonymous_extension(source, "A")
    assert_test("- (void)x;" in extension and "@implementation" not in extension, "extension boundary")


@dataclass(frozen=True)
class CFunctionRecord:
    name: str
    return_type: str
    parameter_text: str
    signature_start_line: int
    signature_start: int
    body_start: int
    body_end: int
    body_text: str
    sanitized_body_text: str


@dataclass(frozen=True, order=True)
class Violation:
    guard_id: str
    path: str
    line: int
    message: str


class GuardCollector:
    def __init__(self) -> None:
        self.seen: set = set()
        self.passed = 0
        self.violations: List[Violation] = []
        self.group_counts: Dict[str, int] = defaultdict(int)

    @property
    def total(self) -> int:
        return self.passed + len(self.violations)

    def check(self, guard_id: str, condition: bool, path: str, line: int, message: str) -> None:
        if not re.fullmatch(r"BRH-(ENV|API|QTN|ALS|CLR|PERM|MAN|KEY|UI|WF)-[A-Z0-9][A-Z0-9-]*", guard_id):
            raise AuditInternalError(f"invalid guard ID: {guard_id}")
        if guard_id in self.seen:
            raise AuditInternalError(f"duplicate guard ID: {guard_id}")
        self.seen.add(guard_id)
        group = guard_id.split("-", 2)[1]
        self.group_counts[group] += 1
        if condition:
            self.passed += 1
        else:
            self.violations.append(Violation(guard_id, path, max(1, line), message))


def guard_slug(value: str) -> str:
    slug = re.sub(r"[^A-Za-z0-9]+", "-", value).strip("-").upper()
    return slug or "ROOT"


def source_from_text(path: str, text: str) -> SourceFile:
    if Path(path).suffix in {".h", ".m", ".mm", ".xm", ".x", ".c", ".cc", ".cpp"}:
        masked, literals = mask_source(text)
    else:
        masked, literals = text, tuple()
    return SourceFile(path, text.encode("utf-8"), text, masked, literals)


def replace_source_text(sources: Mapping[str, SourceFile], path: str, text: str) -> Dict[str, SourceFile]:
    result = dict(sources)
    result[path] = source_from_text(path, text)
    return result


def remove_range(text: str, start: int, end: int) -> str:
    return text[:start] + text[end:]


def source_newline(source: SourceFile) -> str:
    """Return the source's native newline so self-test mutations work after any checkout normalization."""
    return "\r\n" if "\r\n" in source.text else "\n"


def extract_c_functions(source: SourceFile, name: str) -> Tuple[CFunctionRecord, ...]:
    records: List[CFunctionRecord] = []
    pattern = re.compile(r"\b" + re.escape(name) + r"\s*\(")
    for match in pattern.finditer(source.masked):
        open_paren = source.masked.find("(", match.start())
        try:
            close_paren = matching_delimiter(source.masked, open_paren, "(", ")")
        except AuditInternalError:
            continue
        cursor = close_paren + 1
        while cursor < len(source.masked) and source.masked[cursor].isspace():
            cursor += 1
        if cursor >= len(source.masked) or source.masked[cursor] != "{":
            continue
        body_end = matching_delimiter(source.masked, cursor, "{", "}")
        line_start = source.masked.rfind("\n", 0, match.start()) + 1
        signature_prefix = source.text[line_start:match.start()].strip()
        if not signature_prefix or signature_prefix.startswith(("if", "for", "while", "switch", "return")):
            continue
        records.append(CFunctionRecord(
            name=name,
            return_type=" ".join(signature_prefix.split()),
            parameter_text=source.text[open_paren + 1:close_paren],
            signature_start_line=line_number(source.text, line_start),
            signature_start=line_start,
            body_start=cursor,
            body_end=body_end + 1,
            body_text=source.text[cursor:body_end + 1],
            sanitized_body_text=source.masked[cursor:body_end + 1],
        ))
    return tuple(records)


def unique_c_function(source: SourceFile, name: str) -> CFunctionRecord:
    matches = extract_c_functions(source, name)
    if len(matches) != 1:
        raise AuditInternalError(f"expected exactly one C function {name}; found {len(matches)}")
    return matches[0]


def extract_enum_assignments(source: SourceFile, enum_name: str) -> Dict[str, str]:
    pattern = re.compile(
        r"typedef\s+NS_(?:ENUM|OPTIONS)\s*\(\s*[^,]+,\s*" + re.escape(enum_name) + r"\s*\)\s*\{",
        re.S,
    )
    match = pattern.search(source.masked)
    if not match:
        raise AuditInternalError(f"missing enum {enum_name} in {source.path}")
    brace = source.masked.find("{", match.start())
    end = matching_delimiter(source.masked, brace, "{", "}")
    body = source.text[brace + 1:end]
    result: Dict[str, str] = {}
    for item in body.split(","):
        assignment = re.search(r"\b([A-Za-z_]\w*)\s*=\s*(.+?)\s*$", item, re.S)
        if assignment:
            result[assignment.group(1)] = " ".join(assignment.group(2).split())
    return result


def evaluate_integer_expression(expression: str) -> Optional[int]:
    expression = expression.strip()
    direct = re.fullmatch(r"([0-9]+)(?:U|UL|ULL|L|LL)?", expression)
    if direct:
        return int(direct.group(1))
    shift = re.fullmatch(r"1(?:U|UL|ULL|L|LL)?\s*<<\s*([0-9]+)", expression)
    if shift:
        return 1 << int(shift.group(1))
    return None


def extract_assignment_range(source: SourceFile, name: str) -> Tuple[int, int, str, str]:
    matches = list(re.finditer(
        r"\b" + re.escape(name) + r"\b(?:\s*\[[^\]]*\])?\s*=",
        source.masked,
    ))
    candidates: List[Tuple[int, int, str, str]] = []
    for match in matches:
        equals = source.masked.find("=", match.start(), match.end())
        cursor = equals + 1
        paren = bracket = brace = 0
        while cursor < len(source.masked):
            char = source.masked[cursor]
            if char == "(":
                paren += 1
            elif char == ")":
                paren -= 1
            elif char == "[":
                bracket += 1
            elif char == "]":
                bracket -= 1
            elif char == "{":
                brace += 1
            elif char == "}":
                brace -= 1
            elif char == ";" and paren == 0 and bracket == 0 and brace == 0:
                candidates.append((match.start(), cursor + 1,
                                   source.text[equals + 1:cursor],
                                   source.masked[equals + 1:cursor]))
                break
            cursor += 1
    if len(candidates) != 1:
        raise AuditInternalError(f"expected one assignment for {name} in {source.path}; found {len(candidates)}")
    return candidates[0]


def initializer_identifiers(source: SourceFile, name: str, prefix: str) -> Tuple[str, ...]:
    _, _, _, masked = extract_assignment_range(source, name)
    return tuple(re.findall(r"\b" + re.escape(prefix) + r"[A-Za-z0-9_]*\b", masked))


def initializer_literals(source: SourceFile, name: str) -> Tuple[str, ...]:
    start, end, _, _ = extract_assignment_range(source, name)
    return tuple(literal.value for literal in source.literals if start <= literal.start < end)


def parse_shell_readonly_integers(source: SourceFile, prefix: str) -> Dict[str, int]:
    result: Dict[str, int] = {}
    for match in re.finditer(r"(?m)^\s*readonly\s+(" + re.escape(prefix) + r"[A-Za-z0-9_]+)=([0-9]+)\s*$", source.text):
        result[match.group(1)] = int(match.group(2))
    return result


def method_records(source: SourceFile) -> Tuple[MethodRecord, ...]:
    return parse_objc_methods(source.text, source.masked)


def declarations_for_selector(source: SourceFile, selector: str) -> Tuple[MethodRecord, ...]:
    return tuple(method for method in method_records(source) if method.selector == selector and not method.is_definition)


def definitions_for_selector(source: SourceFile, selector: str) -> Tuple[MethodRecord, ...]:
    return tuple(method for method in method_records(source) if method.selector == selector and method.is_definition)


def literal_values_in_range(source: SourceFile, start: int, end: int) -> Tuple[str, ...]:
    return tuple(literal.value for literal in source.literals if start <= literal.start < end)


def identifier_positions(text: str, identifiers: Sequence[str]) -> List[int]:
    positions: List[int] = []
    cursor = 0
    for identifier in identifiers:
        position = text.find(identifier, cursor)
        positions.append(position)
        if position >= 0:
            cursor = position + len(identifier)
    return positions


def positions_strictly_increasing(positions: Sequence[int]) -> bool:
    return all(position >= 0 for position in positions) and list(positions) == sorted(positions) and len(set(positions)) == len(positions)


PUBLIC_CLASS_SELECTORS = ("sharedManager",)
PUBLIC_INSTANCE_SELECTORS = (
    "clearDataForBundleID:completion:",
    "clearDataForBundleID:mode:completion:",
    "hasDataToClear:",
    "completeAppDataWipe:",
    "cleanIconStatePlist:",
    "cleanSiriAnalyticsDatabase:",
    "cleanLaunchServicesDatabase:",
    "refreshSystemServices",
    "clearAppReceiptData:withBundleUUID:",
    "clearSystemLogs:",
    "clearICloudData:",
    "clearMediaData:",
    "clearHealthData:",
    "clearSafariData:",
    "clearURLCredentialsForBundleID:",
    "clearSpotlightIndexes:",
    "clearClipboard",
    "_internalClearAppStateData:",
    "verifyDataCleared:",
    "getDataUsage:",
    "findDataContainerUUIDForBundleID:",
    "findBundleContainerUUIDForBundleID:",
    "findGroupContainerUUIDsForBundleID:",
    "findExtensionDataContainersForBundleID:",
    "hasKeychainItemsForBundleID:",
)

TASK61_REMOVED_SELECTORS = (
    "performFullCleanup:", "performAggressiveCleanupFor:", "completelyWipeContainer:",
    "securelyWipeFile:", "fixPermissionsAndRemovePath:", "fixPermissionsForPath:",
    "clearAppCache:", "clearAppPreferences:", "clearAppCookies:",
    "clearAppWebKitData:", "clearAppGroupData:", "clearPluginKitData:",
    "_internalClearEncryptedData:", "secureDataWipe:", "clearAppKeychain:",
    "clearKeychainData:", "clearKeychainItemsForBundleID:", "universalKeychainWipeForBundleID:",
)

TASK62_REMOVED_SELECTORS = (
    "performSecondaryCleanup:", "clearAppData:", "clearSharedContainers:",
    "clearUserDefaults:", "clearSQLiteDatabases:", "clearPrivateVarData:",
    "clearDeviceDatabase:", "clearInstallationLogs:", "clearNetworkConfigurations:",
    "clearCarrierData:", "clearNetworkData:", "clearDNSCache:", "clearCrashReports:",
    "clearDiagnosticData:", "clearBluetoothData:", "clearPushNotificationData:",
    "clearThumbnailCache:", "clearWebCache:", "clearGameData:", "clearTemporaryFiles:",
    "clearBinaryPlists:", "clearEncryptedData:", "clearJailbreakDetectionLogs:",
    "clearSpotlightData:", "clearSiriData:", "clearSystemLoggerData:",
    "clearASLLogs:", "clearPasteboardData:", "clearURLCache:",
    "clearBackgroundAssets:", "clearSharedStorage:", "clearAppStateData:",
)

REMOVED_SELECTORS = TASK61_REMOVED_SELECTORS + TASK62_REMOVED_SELECTORS

QUARANTINE_SELECTORS = TASK61_REMOVED_SELECTORS + (
    "wipeDirectoryContents:keepDirectoryStructure:",
    "fastWipeDirectoryContents:keepDirectoryStructure:timeoutSec:",
    "finalSweepForContainer:", "wipeWebKitDirectoryContents:",
    "clearAppGroupContainers:withGroupUUIDs:isRootless:",
    "clearAppGroupContainers:withGroupUUIDs:", "clearExtensionContainers:forApp:",
    "cleanAppGroupContainers:", "_wipeRelatedDataContainersForBundleIDs:",
    "_wipeRelatedSystemGroupContainersForIdentifiers:",
    "_wipeContainersInBasePaths:matchingSubstrings:tag:",
    "_wipeDataContainersByIdentifierPrefixOrSubstring:substrings:tag:",
    "_scrubWebKitStateInSharedContainerBase:tag:",
    "cleanAppSpecificFilesInSharedContainer:bundleID:appName:companyName:",
    "deepCleanSystemSharedContainer:bundleID:appName:companyName:",
)

DATA_ONLY_ALIASES = (
    "performSecondaryCleanup:", "clearAppData:", "clearSQLiteDatabases:",
    "clearDeviceDatabase:", "clearNetworkConfigurations:", "clearCarrierData:",
    "clearNetworkData:", "clearDNSCache:", "clearBluetoothData:",
    "clearPushNotificationData:", "clearGameData:", "clearTemporaryFiles:",
    "clearBinaryPlists:", "clearJailbreakDetectionLogs:", "clearSpotlightData:",
    "clearSiriData:", "clearURLCache:", "clearBackgroundAssets:", "clearSharedStorage:",
)

ALIAS_TARGETS: Dict[str, str] = {selector: "completeAppDataWipe:" for selector in DATA_ONLY_ALIASES}
ALIAS_TARGETS.update({
    "clearSharedContainers:": "clearAppGroupData:",
    "clearUserDefaults:": "clearAppPreferences:",
    "clearWebCache:": "clearAppWebKitData:",
    "clearEncryptedData:": "_internalClearEncryptedData:",
    "clearInstallationLogs:": "clearSystemLogs:",
    "clearCrashReports:": "clearSystemLogs:",
    "clearDiagnosticData:": "clearSystemLogs:",
    "clearSystemLoggerData:": "clearSystemLogs:",
    "clearASLLogs:": "clearSystemLogs:",
    "clearPrivateVarData:": "cleanRootHideVarData:",
    "clearThumbnailCache:": "clearThumbnailCaches:",
    "clearPasteboardData:": "clearClipboard",
    "clearAppStateData:": "_internalClearAppStateData:",
})

REQUIRED_FILES = (
    "AppDataCleaner.h", "AppDataCleaner.m", "PXClearRequest.h", "PXClearRequest.m",
    "PXClearResult.h", "PXClearResult.m", "AppDataBackupManager.h", "AppDataBackupManager.m",
    "PXBackupManifestV4.h", "PXBackupManifestV4.m", "PXBackupManifestValidator.h",
    "PXBackupManifestValidator.m", "PXBackupDirectoryDiscovery.h", "PXBackupDirectoryDiscovery.m",
    "PXRestoreResult.h", "PXRestoreResult.m", "AppDataBackupRestoreViewController.h",
    "AppDataBackupRestoreViewController.m", "KeychainHelper/PXKeychainHelperExitCode.h",
    "KeychainHelper/PXKeychainHelperResult.h", "KeychainHelper/PXKeychainHelperResult.m",
    "KeychainHelper/KeychainBackupHelper.h", "KeychainHelper/KeychainBackupHelper.m",
    "KeychainHelper/backup_helper.m", "scripts/keychain_backup.sh",
    ".github/workflows/build-ios-arm.yml", "Makefile", "ProjectXViewController.m", "main.m",
)

PRODUCTION_EXTENSIONS = {".h", ".m", ".mm", ".xm", ".x", ".c", ".cc", ".cpp"}
EXCLUDED_DIRECTORIES = {
    ".git", ".github", ".theos", "packages", "docs", "old", "backupmanager",
    "backupnew", "hiddenjailbreak", "JailbreakDetector",
}


def production_paths(root: Path) -> Tuple[str, ...]:
    paths: List[str] = []
    for path in root.rglob("*"):
        if not path.is_file() or path.suffix not in PRODUCTION_EXTENSIONS:
            continue
        relative = path.relative_to(root)
        if any(part in EXCLUDED_DIRECTORIES for part in relative.parts):
            continue
        paths.append(relative.as_posix())
    return tuple(sorted(paths))


def load_repository_sources(root: Path, collector: Optional[GuardCollector] = None) -> Dict[str, SourceFile]:
    paths = set(REQUIRED_FILES)
    paths.update(production_paths(root))
    sources: Dict[str, SourceFile] = {}
    for relative_path in sorted(paths):
        source = read_source(root, relative_path)
        sources[relative_path] = source
        if collector is not None:
            slug = guard_slug(relative_path)
            collector.check(f"BRH-ENV-FILE-{slug}-BYTES", isinstance(source.data, bytes),
                            relative_path, 1, "required file must be readable as bytes")
            collector.check(f"BRH-ENV-FILE-{slug}-UTF8", source.text.encode("utf-8") == source.data,
                            relative_path, 1, "required file must decode as strict UTF-8")
            collector.check(f"BRH-ENV-FILE-{slug}-NUL", b"\x00" not in source.data,
                            relative_path, 1, "required file contains a NUL byte")
            collector.check(f"BRH-ENV-FILE-{slug}-CONFLICT",
                            not any(marker in source.text for marker in ("<<<<<<<", "=======", ">>>>>>>")),
                            relative_path, 1, "required file contains a merge conflict marker")
    return sources


def source_line_for_token(source: SourceFile, token: str) -> int:
    offset = source.text.find(token)
    return line_number(source.text, offset) if offset >= 0 else 1


def removed_selector_reference_count(source: SourceFile, selector: str) -> int:
    first_piece = selector.split(":", 1)[0]
    code_count = len(re.findall(r"\b" + re.escape(first_piece) + r"\s*:", source.masked))
    literal_count = sum(1 for literal in source.literals if literal.value == selector)
    return code_count + literal_count


def guard_public_and_removed_api(sources: Mapping[str, SourceFile], collector: GuardCollector) -> None:
    header = sources["AppDataCleaner.h"]
    header_methods = method_records(header)
    class_methods = [method.selector for method in header_methods if method.kind == "+" and not method.is_definition]
    instance_methods = [method.selector for method in header_methods if method.kind == "-" and not method.is_definition]
    collector.check("BRH-API-PUBLIC-CLASS-EXACT", Counter(class_methods) == Counter(PUBLIC_CLASS_SELECTORS),
                    header.path, 1, "AppDataCleaner class-method interface differs from the exact sharedManager set")
    collector.check("BRH-API-PUBLIC-INSTANCE-EXACT", Counter(instance_methods) == Counter(PUBLIC_INSTANCE_SELECTORS),
                    header.path, 1, "AppDataCleaner instance-method interface differs from the exact 25-selector set")
    collector.check("BRH-API-PUBLIC-CLASS-COUNT", len(class_methods) == 1,
                    header.path, 1, "AppDataCleaner must expose exactly one class method")
    collector.check("BRH-API-PUBLIC-INSTANCE-COUNT", len(instance_methods) == 25,
                    header.path, 1, "AppDataCleaner must expose exactly 25 instance methods")
    for selector in PUBLIC_CLASS_SELECTORS:
        slug = guard_slug(selector)
        collector.check(f"BRH-API-PUBLIC-CLASS-{slug}", class_methods.count(selector) == 1,
                        header.path, source_line_for_token(header, selector),
                        f"public class selector {selector} must appear exactly once")
    for selector in PUBLIC_INSTANCE_SELECTORS:
        slug = guard_slug(selector)
        collector.check(f"BRH-API-PUBLIC-INSTANCE-{slug}", instance_methods.count(selector) == 1,
                        header.path, source_line_for_token(header, selector.split(':')[0]),
                        f"public instance selector {selector} must appear exactly once")

    cleaner = sources["AppDataCleaner.m"]
    _, _, extension_text, extension_masked = extract_anonymous_extension(cleaner, "AppDataCleaner")
    extension_methods = parse_objc_methods(extension_text, extension_masked)
    implementation_methods = method_records(cleaner)
    production_headers = [source for path, source in sources.items()
                          if path.endswith(".h") and not any(part in EXCLUDED_DIRECTORIES for part in Path(path).parts)]
    external_sources = [source for path, source in sources.items()
                        if Path(path).suffix in PRODUCTION_EXTENSIONS and path not in ("AppDataCleaner.h", "AppDataCleaner.m")]

    for selector in REMOVED_SELECTORS:
        slug = guard_slug(selector)
        public_count = sum(1 for source in production_headers
                           for method in method_records(source)
                           if not method.is_definition and method.selector == selector)
        private_count = sum(1 for method in extension_methods
                            if not method.is_definition and method.selector == selector and method.kind == "-")
        definition_count = sum(1 for method in implementation_methods
                               if method.is_definition and method.selector == selector and method.kind == "-")
        external_count = sum(removed_selector_reference_count(source, selector) for source in external_sources)
        collector.check(f"BRH-API-REMOVED-PUBLIC-{slug}", public_count == 0,
                        "AppDataCleaner.h", 1,
                        f"removed selector {selector} is declared in a production header")
        collector.check(f"BRH-API-REMOVED-PRIVATE-{slug}", private_count == 1,
                        "AppDataCleaner.m", 1,
                        f"removed selector {selector} must have exactly one AppDataCleaner anonymous-extension declaration")
        collector.check(f"BRH-API-REMOVED-IMPL-{slug}", definition_count == 1,
                        "AppDataCleaner.m", 1,
                        f"removed selector {selector} must retain exactly one runtime implementation")
        collector.check(f"BRH-API-REMOVED-EXTERNAL-{slug}", external_count == 0,
                        "AppDataCleaner.m", 1,
                        f"removed selector {selector} has an external direct or dynamic source reference")


def normalized_statement_body(body: str) -> str:
    body = body.strip()
    if body.startswith("{") and body.endswith("}"):
        body = body[1:-1]
    return re.sub(r"\s+", " ", body).strip()


def guard_quarantine(sources: Mapping[str, SourceFile], collector: GuardCollector) -> None:
    source = sources["AppDataCleaner.m"]
    methods = method_records(source)
    combined_bodies: List[str] = []
    for selector in QUARANTINE_SELECTORS:
        slug = guard_slug(selector)
        matches = [method for method in methods if method.selector == selector and method.is_definition]
        collector.check(f"BRH-QTN-DEFINITION-{slug}", len(matches) == 1, source.path, 1,
                        f"quarantine selector {selector} must have exactly one implementation")
        if len(matches) != 1:
            collector.check(f"BRH-QTN-ARGS-{slug}", False, source.path, 1,
                            f"cannot verify quarantine arguments for {selector}")
            collector.check(f"BRH-QTN-LOGGER-{slug}", False, source.path, 1,
                            f"cannot verify quarantine logger call for {selector}")
            collector.check(f"BRH-QTN-SHAPE-{slug}", False, source.path, 1,
                            f"cannot verify quarantine body shape for {selector}")
            continue
        method = matches[0]
        combined_bodies.append(method.sanitized_body_text)
        body = normalized_statement_body(method.sanitized_body_text)
        casts_ok = all(len(re.findall(r"\(\s*void\s*\)\s*" + re.escape(argument) + r"\s*;", body)) == 1
                       for argument in method.argument_names)
        casts_ok = casts_ok and len(re.findall(r"\(\s*void\s*\)\s*[A-Za-z_]\w*\s*;", body)) == len(method.argument_names)
        logger_count = body.count("PXLogQuarantinedLegacyClearSelector(_cmd);")
        collector.check(f"BRH-QTN-ARGS-{slug}", casts_ok, source.path, method.signature_start_line,
                        f"quarantine selector {selector} must cast each argument unused exactly once in signature order")
        collector.check(f"BRH-QTN-LOGGER-{slug}", logger_count == 1, source.path, method.signature_start_line,
                        f"quarantine selector {selector} must log selector identity exactly once")
        expected_parts = [f"(void){argument};" for argument in method.argument_names]
        compact = re.sub(r"\s+", "", body)
        expected_compact = "".join(expected_parts) + "PXLogQuarantinedLegacyClearSelector(_cmd);"
        if selector == "securelyWipeFile:":
            expected_compact += "returnNO;"
        shape_ok = compact == expected_compact
        collector.check(f"BRH-QTN-SHAPE-{slug}", shape_ok, source.path, method.signature_start_line,
                        f"quarantine selector {selector} contains executable behavior beyond the accepted fail-closed shim")

    secure_matches = [method for method in methods if method.selector == "securelyWipeFile:" and method.is_definition]
    secure_body = secure_matches[0].sanitized_body_text if len(secure_matches) == 1 else ""
    collector.check("BRH-QTN-SECURE-RETURN", secure_body.count("return NO;") == 1 and "return YES;" not in secure_body,
                    source.path, source_line_for_token(source, "securelyWipeFile"),
                    "securelyWipeFile: must fail closed with exactly one return NO and no return YES")

    logger_matches = extract_c_functions(source, "PXLogQuarantinedLegacyClearSelector")
    collector.check("BRH-QTN-LOGGER-DEFINITION", len(logger_matches) == 1, source.path, 1,
                    "quarantine logger must have exactly one definition")
    if len(logger_matches) == 1:
        logger = logger_matches[0]
        parameter = " ".join(logger.parameter_text.split())
        collector.check("BRH-QTN-LOGGER-PARAMETER", parameter == "SEL selector", source.path,
                        logger.signature_start_line, "quarantine logger parameter must be exactly SEL selector")
        collector.check("BRH-QTN-LOGGER-NSLOG", logger.sanitized_body_text.count("NSLog(") == 1,
                        source.path, logger.signature_start_line, "quarantine logger must call NSLog exactly once")
        collector.check("BRH-QTN-LOGGER-SELECTOR", logger.sanitized_body_text.count("NSStringFromSelector(selector)") == 1,
                        source.path, logger.signature_start_line,
                        "quarantine logger must stringify only the selector parameter")
        privacy_tokens = ("path", "bundleID", "UUID", "group", "entitlement", "command", "profile", "container", "Keychain")
        privacy_ok = all(re.search(r"\b" + re.escape(token) + r"\b", logger.sanitized_body_text, re.I) is None
                         for token in privacy_tokens)
        collector.check("BRH-QTN-LOGGER-PRIVACY", privacy_ok, source.path, logger.signature_start_line,
                        "quarantine logger references path, identity, entitlement, command, profile, container or Keychain data")
        forbidden_logger = ("NSFileManager", "SecItem", "CommandRunner", "dispatch_", "NSUserDefaults", "UIApplication",
                            "clearDataForBundleID", "completeAppDataWipe")
        collector.check("BRH-QTN-LOGGER-SIDE-EFFECTS",
                        not any(token in logger.sanitized_body_text for token in forbidden_logger),
                        source.path, logger.signature_start_line,
                        "quarantine logger contains a filesystem, process, Security, Clear, dispatch, defaults or lifecycle operation")
    else:
        for guard_id, message in (
            ("BRH-QTN-LOGGER-PARAMETER", "cannot verify quarantine logger parameter"),
            ("BRH-QTN-LOGGER-NSLOG", "cannot verify quarantine logger NSLog count"),
            ("BRH-QTN-LOGGER-SELECTOR", "cannot verify quarantine selector formatting"),
            ("BRH-QTN-LOGGER-PRIVACY", "cannot verify quarantine logger privacy"),
            ("BRH-QTN-LOGGER-SIDE-EFFECTS", "cannot verify quarantine logger side effects"),
        ):
            collector.check(guard_id, False, source.path, 1, message)

    forbidden_tokens = (
        "NSFileManager", "fileExistsAtPath", "contentsOfDirectoryAtPath", "enumeratorAtPath",
        "dictionaryWithContentsOfFile", "MCMMetadataIdentifier", "PXDataContainerResolver",
        "AppGroupContainerResolver", "PXDestructivePathValidator", "PXShellQuote", "CommandRunner",
        "runCommand", "runExecutable", "removeItem", "createDirectory", "writeToFile", "moveItem",
        "copyItem", "unlink", "rmdir", "sqlite3", "SecItem", "_wipeSelectedKeychainForBundleID",
        "PXKill", "killall", "UIApplication", "NSUserDefaults", "dispatch_async", "dispatch_apply",
        "sleep", "hasPrefix", "containsString", "lowercaseString", "clearDataForBundleID",
        "completeAppDataWipe",
    )
    combined = "\n".join(combined_bodies)
    for token in forbidden_tokens:
        collector.check(f"BRH-QTN-FORBIDDEN-{guard_slug(token)}",
                        re.search(r"\b" + re.escape(token) + r"\b", combined) is None,
                        source.path, 1, f"quarantine shim bodies contain forbidden token {token}")


def guard_aliases(sources: Mapping[str, SourceFile], collector: GuardCollector) -> None:
    source = sources["AppDataCleaner.m"]
    methods = method_records(source)
    group_counts = {"data": 0, "quarantine": 0, "logs": 0, "direct": 0}
    for selector, target in ALIAS_TARGETS.items():
        slug = guard_slug(selector)
        matches = [method for method in methods if method.selector == selector and method.is_definition]
        collector.check(f"BRH-ALS-DEFINITION-{slug}", len(matches) == 1, source.path, 1,
                        f"alias {selector} must retain exactly one implementation")
        if len(matches) != 1:
            collector.check(f"BRH-ALS-MAP-{slug}", False, source.path, 1,
                            f"cannot verify target mapping for alias {selector}")
            collector.check(f"BRH-ALS-SINGLE-{slug}", False, source.path, 1,
                            f"cannot verify single-send body for alias {selector}")
            collector.check(f"BRH-ALS-SHAPE-{slug}", False, source.path, 1,
                            f"cannot verify body shape for alias {selector}")
            continue
        method = matches[0]
        sends = extract_self_message_selectors(method.sanitized_body_text)
        collector.check(f"BRH-ALS-MAP-{slug}", sends == (target,), source.path, method.signature_start_line,
                        f"alias {selector} must send exactly to {target}")
        bracket_sends = method.sanitized_body_text.count("[")
        collector.check(f"BRH-ALS-SINGLE-{slug}", len(sends) == 1 and bracket_sends == 1,
                        source.path, method.signature_start_line,
                        f"alias {selector} must contain exactly one Objective-C message send")
        forbidden = re.search(r"\b(if|for|while|switch|dispatch_|NSLog|return|SecItem|NSFileManager)\b",
                              method.sanitized_body_text)
        collector.check(f"BRH-ALS-SHAPE-{slug}", forbidden is None,
                        source.path, method.signature_start_line,
                        f"alias {selector} contains control flow, logging, return fabrication or new mutation")
        if selector in DATA_ONLY_ALIASES:
            group_counts["data"] += 1
        elif selector in ("clearSharedContainers:", "clearUserDefaults:", "clearWebCache:", "clearEncryptedData:"):
            group_counts["quarantine"] += 1
        elif target == "clearSystemLogs:":
            group_counts["logs"] += 1
        else:
            group_counts["direct"] += 1
    collector.check("BRH-ALS-GROUP-DATA", group_counts["data"] == 19, source.path, 1,
                    "data-only alias mapping group must contain exactly 19 selectors")
    collector.check("BRH-ALS-GROUP-QUARANTINE", group_counts["quarantine"] == 4, source.path, 1,
                    "quarantine-target alias mapping group must contain exactly 4 selectors")
    collector.check("BRH-ALS-GROUP-LOGS", group_counts["logs"] == 5, source.path, 1,
                    "system-log alias mapping group must contain exactly 5 selectors")
    collector.check("BRH-ALS-GROUP-DIRECT", group_counts["direct"] == 4, source.path, 1,
                    "direct-mutator alias mapping group must contain exactly 4 selectors")


def exact_scope_enum() -> Dict[str, int]:
    return {
        "PXClearScopeApplicationData": 1 << 0,
        "PXClearScopeExtensionData": 1 << 1,
        "PXClearScopeAppGroups": 1 << 2,
        "PXClearScopePluginKitData": 1 << 3,
        "PXClearScopeKeychain": 1 << 4,
    }


def operand_set(source: SourceFile, assignment: str, prefix: str) -> Tuple[str, ...]:
    return initializer_identifiers(source, assignment, prefix)


def guard_clear(sources: Mapping[str, SourceFile], collector: GuardCollector) -> None:
    header = sources["PXClearRequest.h"]
    request_impl = sources["PXClearRequest.m"]
    cleaner = sources["AppDataCleaner.m"]
    enum_values = extract_enum_assignments(header, "PXClearScope")
    evaluated = {name: evaluate_integer_expression(value) for name, value in enum_values.items()}
    collector.check("BRH-CLR-SCOPE-ENUM", evaluated == exact_scope_enum(), header.path, 1,
                    "PXClearScope must contain exactly five canonical bit values and no aliases")
    expected_five = tuple(exact_scope_enum().keys())
    expected_four = expected_five[:-1]
    collector.check("BRH-CLR-KNOWN-MASK", operand_set(request_impl, "PXClearScopeKnownMask", "PXClearScope") == expected_five,
                    request_impl.path, source_line_for_token(request_impl, "PXClearScopeKnownMask"),
                    "PXClearScopeKnownMask must contain the exact five-scope set")
    collector.check("BRH-CLR-DEFAULT-MASK", operand_set(request_impl, "PXClearScopeDefaultMask", "PXClearScope") == expected_five,
                    request_impl.path, source_line_for_token(request_impl, "PXClearScopeDefaultMask"),
                    "PXClearScopeDefaultMask must contain the exact five-scope set")
    collector.check("BRH-CLR-DATA-MASK", operand_set(cleaner, "PXMigratedDataClearScopes", "PXClearScope") == expected_four,
                    cleaner.path, source_line_for_token(cleaner, "PXMigratedDataClearScopes"),
                    "PXMigratedDataClearScopes must contain exactly four data scopes and exclude Keychain")
    collector.check("BRH-CLR-FULL-MASK", operand_set(cleaner, "PXMigratedFullClearScopes", "PXClearScope") == expected_five,
                    cleaner.path, source_line_for_token(cleaner, "PXMigratedFullClearScopes"),
                    "PXMigratedFullClearScopes must contain the exact five-scope set")

    methods = method_records(cleaner)
    full_matches = [method for method in methods if method.selector == "clearDataForBundleID:mode:completion:" and method.is_definition]
    data_matches = [method for method in methods if method.selector == "completeAppDataWipe:" and method.is_definition]
    collector.check("BRH-CLR-FULL-DEFINITION", len(full_matches) == 1, cleaner.path, 1,
                    "full typed Clear authority must have exactly one implementation")
    collector.check("BRH-CLR-DATA-DEFINITION", len(data_matches) == 1, cleaner.path, 1,
                    "data-only compatibility authority must have exactly one implementation")
    if len(full_matches) == 1:
        body = full_matches[0].sanitized_body_text
        required_order = (
            "scopes:PXMigratedFullClearScopes", "scopes:PXMigratedDataClearScopes",
            "_keychainClearPlanForBundleIdentifier", "_completeDataWipeForMigratedRequest",
            "_keychainComponentForPlan", "addObject:keychainComponent", "initWithRequest:fullRequest",
        )
        collector.check("BRH-CLR-FULL-ROUTE", positions_strictly_increasing(identifier_positions(body, required_order)),
                        cleaner.path, full_matches[0].signature_start_line,
                        "full Clear route must plan Keychain, run four-scope data, append Keychain and construct final result in order")
        precedence_start = body.find("failurePrecedence")
        precedence_end = body.find("for (NSNumber *scopeNumber", precedence_start)
        precedence_body = body[precedence_start:precedence_end] if precedence_start >= 0 and precedence_end >= 0 else ""
        precedence = tuple(re.findall(r"PXClearScope(?:ApplicationData|ExtensionData|AppGroups|PluginKitData|Keychain)", precedence_body))
        collector.check("BRH-CLR-FAILURE-PRECEDENCE", precedence == expected_five,
                        cleaner.path, full_matches[0].signature_start_line,
                        "full Clear failure precedence must remain ApplicationData, ExtensionData, AppGroups, PluginKitData, Keychain")
        removed_hits = [selector for selector in REMOVED_SELECTORS
                        if re.search(r"\b" + re.escape(selector.split(':')[0]) + r"\s*:", body)]
        collector.check("BRH-CLR-FULL-NO-REMOVED", not removed_hits, cleaner.path,
                        full_matches[0].signature_start_line,
                        "full Clear authority sends a message to a removed compatibility selector")
    else:
        collector.check("BRH-CLR-FULL-ROUTE", False, cleaner.path, 1, "cannot verify full Clear route")
        collector.check("BRH-CLR-FAILURE-PRECEDENCE", False, cleaner.path, 1, "cannot verify failure precedence")
        collector.check("BRH-CLR-FULL-NO-REMOVED", False, cleaner.path, 1, "cannot verify removed-selector isolation")
    if len(data_matches) == 1:
        body = data_matches[0].sanitized_body_text
        collector.check("BRH-CLR-DATA-ROUTE",
                        "scopes:PXMigratedDataClearScopes" in body and "_completeDataWipeForMigratedRequest" in body,
                        cleaner.path, data_matches[0].signature_start_line,
                        "completeAppDataWipe: must construct and execute the four-scope migrated request")
        collector.check("BRH-CLR-DATA-NO-KEYCHAIN",
                        "PXClearScopeKeychain" not in body and "Keychain" not in body,
                        cleaner.path, data_matches[0].signature_start_line,
                        "completeAppDataWipe: must not plan or execute Keychain")
        removed_hits = [selector for selector in REMOVED_SELECTORS
                        if selector != "completeAppDataWipe:" and
                        re.search(r"\b" + re.escape(selector.split(':')[0]) + r"\s*:", body)]
        collector.check("BRH-CLR-DATA-NO-REMOVED", not removed_hits, cleaner.path,
                        data_matches[0].signature_start_line,
                        "data-only authority sends a message to a removed compatibility selector")
    else:
        collector.check("BRH-CLR-DATA-ROUTE", False, cleaner.path, 1, "cannot verify data-only route")
        collector.check("BRH-CLR-DATA-NO-KEYCHAIN", False, cleaner.path, 1, "cannot verify Keychain exclusion")
        collector.check("BRH-CLR-DATA-NO-REMOVED", False, cleaner.path, 1, "cannot verify removed-selector isolation")


def active_command_values(sources: Mapping[str, SourceFile]) -> List[Tuple[str, int, str]]:
    commands: List[Tuple[str, int, str]] = []
    for path, source in sources.items():
        suffix = Path(path).suffix
        if suffix in PRODUCTION_EXTENSIONS:
            for literal in source.literals:
                commands.append((path, literal.line, literal.value))
        elif suffix == ".sh":
            for number, line in enumerate(source.text.splitlines(), 1):
                stripped = line.strip()
                if stripped and not stripped.startswith("#"):
                    commands.append((path, number, stripped))
    return commands


def guard_permissions(sources: Mapping[str, SourceFile], collector: GuardCollector) -> None:
    commands = active_command_values(sources)
    chmod_recursive = [(path, line, value) for path, line, value in commands if re.search(r"\bchmod\s+-R\b", value)]
    find_chmod = [(path, line, value) for path, line, value in commands
                  if re.search(r"\bfind\b.*\b-exec\b.*\bchmod\b", value)]
    chown_recursive = [(path, line, value) for path, line, value in commands if re.search(r"\bchown\s+-R\b", value)]
    clear_chown_recursive = [hit for hit in chown_recursive if hit[0] != "AppDataBackupManager.m"]
    restore_chown = [hit for hit in chown_recursive if hit[0] == "AppDataBackupManager.m"]
    chflags_recursive = [(path, line, value) for path, line, value in commands if re.search(r"\bchflags\s+-R\b", value)]
    touch_markers = [(path, line, value) for path, line, value in commands
                     if re.search(r"(?:^|[;&|]\s*|\s)touch\s+", value) and
                     (".nomedia" in value or ".initialized" in value or "AssistantServices" in value)]
    collector.check("BRH-PERM-CHMOD-RECURSIVE", len(chmod_recursive) == 0,
                    chmod_recursive[0][0] if chmod_recursive else "AppDataCleaner.m",
                    chmod_recursive[0][1] if chmod_recursive else 1,
                    "recursive chmod command is prohibited")
    collector.check("BRH-PERM-FIND-CHMOD", len(find_chmod) == 0,
                    find_chmod[0][0] if find_chmod else "AppDataCleaner.m",
                    find_chmod[0][1] if find_chmod else 1,
                    "find -exec chmod command is prohibited")
    # Phase 2 transactional Restore intentionally retained five post-cleanup ownership corrections.
    # The legacy Clear/public compatibility surface must remain free of recursive ownership traversal.
    collector.check("BRH-PERM-CHOWN-RECURSIVE-CLEAR", len(clear_chown_recursive) == 0,
                    clear_chown_recursive[0][0] if clear_chown_recursive else "AppDataCleaner.m",
                    clear_chown_recursive[0][1] if clear_chown_recursive else 1,
                    "recursive chown is prohibited outside the accepted transactional Restore ownership corrections")
    collector.check("BRH-PERM-RESTORE-CHOWN-BOUNDED", len(restore_chown) == 5,
                    "AppDataBackupManager.m", source_line_for_token(sources["AppDataBackupManager.m"], "chown -R"),
                    "transactional Restore recursive ownership correction count changed from the accepted five routes")
    collector.check("BRH-PERM-CHFLAGS-COUNT", len(chflags_recursive) == 1,
                    chflags_recursive[0][0] if chflags_recursive else "AppDataCleaner.m",
                    chflags_recursive[0][1] if chflags_recursive else 1,
                    "exactly one recursive chflags command must remain")
    cleaner = sources["AppDataCleaner.m"]
    wipe_function = unique_c_function(cleaner, "PXShellValidatedApplicationDataWipe")
    collector.check("BRH-PERM-CHFLAGS-ROUTE",
                    len(chflags_recursive) == 1 and "chflags -R" in " ".join(literal_values_in_range(cleaner, wipe_function.body_start, wipe_function.body_end)),
                    cleaner.path, wipe_function.signature_start_line,
                    "the sole chflags -R command must remain inside PXShellValidatedApplicationDataWipe")
    combined_values = "\n".join(value for _, _, value in commands)
    collector.check("BRH-PERM-MARKER-NOMEDIA", ".nomedia" not in combined_values,
                    "AppDataCleaner.m", 1, ".nomedia marker creation is prohibited")
    collector.check("BRH-PERM-MARKER-INITIALIZED", ".initialized" not in combined_values,
                    "AppDataCleaner.m", 1, ".initialized marker creation is prohibited")
    collector.check("BRH-PERM-MARKER-TOUCH", len(touch_markers) == 0,
                    touch_markers[0][0] if touch_markers else "AppDataCleaner.m",
                    touch_markers[0][1] if touch_markers else 1,
                    "active shell marker touch command is prohibited")
    collector.check("BRH-PERM-FINAL-SWEEP", "PXShellFinalSweep" not in combined_values and "PXShellFinalSweep" not in cleaner.masked,
                    cleaner.path, 1, "legacy PXShellFinalSweep route is prohibited")
    collector.check("BRH-PERM-ASSISTANT-SERVICES", "AssistantServices" not in combined_values,
                    cleaner.path, 1, "AssistantServices destructive target is prohibited")

    receipt_matches = definitions_for_selector(cleaner, "clearAppReceiptData:withBundleUUID:")
    collector.check("BRH-PERM-RECEIPT-DEFINITION", len(receipt_matches) == 1, cleaner.path, 1,
                    "receipt compatibility method must have exactly one implementation")
    if len(receipt_matches) == 1:
        body = receipt_matches[0].sanitized_body_text
        literals = literal_values_in_range(cleaner, receipt_matches[0].body_start or 0, receipt_matches[0].body_end or 0)
        collector.check("BRH-PERM-RECEIPT-READONLY",
                        "(void)bundleUUID;" in body and any("Skipping receipt mutation" in value and "read-only" in value for value in literals),
                        cleaner.path, receipt_matches[0].signature_start_line,
                        "receipt method must cast bundleUUID unused and emit the read-only skip log")
        forbidden = ("NSFileManager", "removeItem", "writeToFile", "CommandRunner", "run:", "chmod", "chown", "chflags")
        collector.check("BRH-PERM-RECEIPT-NO-MUTATION", not any(token in body for token in forbidden),
                        cleaner.path, receipt_matches[0].signature_start_line,
                        "receipt method must not mutate files, run shell commands or change permissions")
    else:
        collector.check("BRH-PERM-RECEIPT-READONLY", False, cleaner.path, 1, "cannot verify receipt read-only log")
        collector.check("BRH-PERM-RECEIPT-NO-MUTATION", False, cleaner.path, 1, "cannot verify receipt mutation ban")


def guard_manifest(sources: Mapping[str, SourceFile], collector: GuardCollector) -> None:
    manager = sources["AppDataBackupManager.m"]
    discovery = sources["PXBackupDirectoryDiscovery.m"]
    ui = sources["AppDataBackupRestoreViewController.m"]
    v4 = sources["PXBackupManifestV4.m"]
    support = unique_c_function(manager, "PXBackupManifestVersionIsSupported")
    support_numbers = tuple(sorted(set(int(value) for value in re.findall(r"value\s*==\s*([0-9]+)", support.sanitized_body_text))))
    collector.check("BRH-MAN-MANAGER-VERSIONS", support_numbers == (2, 3, 4), manager.path,
                    support.signature_start_line, "operational manager Restore versions must be exactly 2, 3 and 4")
    discovery_condition = re.search(
        r"version\s*!=\s*2(?:ULL|UL|U|LL|L)?\s*&&\s*"
        r"version\s*!=\s*3(?:ULL|UL|U|LL|L)?\s*&&\s*"
        r"version\s*!=\s*4(?:ULL|UL|U|LL|L)?",
        discovery.masked,
        re.S,
    )
    collector.check("BRH-MAN-DISCOVERY-VERSIONS", discovery_condition is not None, discovery.path,
                    source_line_for_token(discovery, "version != 2"),
                    "backup directory discovery must accept exactly manifest versions 2, 3 and 4")
    ui_reader = unique_c_function(ui, "PXReadSupportedManifestVersion")
    collector.check("BRH-MAN-UI-VERSION-RANGE",
                    "version < 2 || version > 5" in " ".join(ui_reader.sanitized_body_text.split()),
                    ui.path, ui_reader.signature_start_line,
                    "confirmation inspection compatibility range must remain 2 through 5 inclusive")

    expected_constants = {
        "PXBackupManifestV4Version": "4",
        "PXBackupManifestV4SchemaRevision": "2",
    }
    for name, expected in expected_constants.items():
        _, _, text, _ = extract_assignment_range(v4, name)
        collector.check(f"BRH-MAN-V4-{guard_slug(name)}", " ".join(text.split()) == expected,
                        v4.path, source_line_for_token(v4, name), f"{name} must equal {expected}")
    expected_strings = {
        "PXBackupManifestV4SchemaIdentifier": "com.hydra.projectx.backup-manifest",
        "PXBackupManifestV4DigestAlgorithm": "sha256",
        "PXBackupManifestV4PublicationProtocol": "atomic-directory-v1",
        "PXBackupManifestV4ContentStateComplete": "complete",
    }
    guard_names = {
        "PXBackupManifestV4SchemaIdentifier": "SCHEMA",
        "PXBackupManifestV4DigestAlgorithm": "DIGEST",
        "PXBackupManifestV4PublicationProtocol": "PUBLICATION",
        "PXBackupManifestV4ContentStateComplete": "CONTENT",
    }
    for name, expected in expected_strings.items():
        values = initializer_literals(v4, name)
        collector.check(f"BRH-MAN-V4-{guard_names[name]}", values == (expected,), v4.path,
                        source_line_for_token(v4, name), f"{name} must equal {expected}")


def guard_keychain(sources: Mapping[str, SourceFile], collector: GuardCollector) -> None:
    exit_header = sources["KeychainHelper/PXKeychainHelperExitCode.h"]
    shell = sources["scripts/keychain_backup.sh"]
    helper = sources["KeychainHelper/KeychainBackupHelper.m"]
    backup_helper = sources["KeychainHelper/backup_helper.m"]
    cleaner = sources["AppDataCleaner.m"]
    manager = sources["AppDataBackupManager.m"]
    enum = extract_enum_assignments(exit_header, "PXKeychainHelperExitCode")
    enum_values = {name: evaluate_integer_expression(value) for name, value in enum.items()}
    expected_enum = {
        "PXKeychainHelperExitCodeCompleted": 0,
        "PXKeychainHelperExitCodePartial": 10,
        "PXKeychainHelperExitCodeInvalidArguments": 20,
        "PXKeychainHelperExitCodeInvalidInput": 21,
        "PXKeychainHelperExitCodeAccessDenied": 30,
        "PXKeychainHelperExitCodeOperationFailed": 40,
        "PXKeychainHelperExitCodeProtocolFailure": 50,
        "PXKeychainHelperExitCodeHelperUnavailable": 60,
        "PXKeychainHelperExitCodeTargetUnavailable": 61,
        "PXKeychainHelperExitCodeEntitlementFailure": 62,
        "PXKeychainHelperExitCodeWorkspaceFailure": 63,
        "PXKeychainHelperExitCodeSigningFailure": 64,
        "PXKeychainHelperExitCodeDependencyUnavailable": 65,
    }
    shell_values = parse_shell_readonly_integers(shell, "PX_KEYCHAIN_EXIT_")
    translated_shell = {
        "PXKeychainHelperExitCode" + "".join(part.title() for part in name[len("PX_KEYCHAIN_EXIT_"):].lower().split("_")): value
        for name, value in shell_values.items()
    }
    collector.check("BRH-KEY-EXIT-ENUM", enum_values == expected_enum, exit_header.path, 1,
                    "Keychain helper Objective-C exit-code enum differs from the exact contract")
    collector.check("BRH-KEY-EXIT-PARITY", translated_shell == expected_enum, shell.path, 1,
                    "Keychain wrapper exit-code dictionary differs from the Objective-C enum")

    helper_main = unique_c_function(backup_helper, "main")
    helper_main_text = " ".join(helper_main.body_text.split())
    helper_cli_contract = (
        'NSString *requestedCSV = args[@"requested-groups"];',
        'NSString *effectiveEntitlementsPath = args[@"effective-entitlements-file"];',
        'Missing required group-report metadata',
        'Operational access groups do not match requested metadata',
    )
    collector.check("BRH-KEY-CLI-METADATA-CONTRACT",
                    all(token in helper_main_text for token in helper_cli_contract),
                    backup_helper.path, helper_main.signature_start_line,
                    "direct helper must require requested-group and effective-entitlements metadata")

    clear_wipe_selector = (
        "_executeKeychainWipeForBundleIdentifier:selectedGroups:"
        "applicationIdentifier:systemApplication:error:"
    )
    clear_wipe_matches = definitions_for_selector(cleaner, clear_wipe_selector)
    expected_clear_arguments = (
        'arguments:@[ @"--action", @"wipe", @"--groups", groupsCSV, '
        '@"--requested-groups", groupsCSV, '
        '@"--effective-entitlements-file", entitlementsPath ]'
    )
    clear_wipe_body = " ".join(clear_wipe_matches[0].body_text.split()) if len(clear_wipe_matches) == 1 else ""
    collector.check("BRH-KEY-CLEAR-CLI-METADATA",
                    len(clear_wipe_matches) == 1 and clear_wipe_body.count(expected_clear_arguments) == 1,
                    cleaner.path, clear_wipe_matches[0].signature_start_line if clear_wipe_matches else 1,
                    "AppDataCleaner wipe invocation must pass the complete helper metadata contract")

    keychain_sources = [source for path, source in sources.items() if path.startswith("KeychainHelper/") and path.endswith(".m")]
    delete_occurrences = [(source.path, line_number(source.text, match.start()))
                          for source in keychain_sources
                          for match in re.finditer(r"\bSecItemDelete\s*\(", source.masked)]
    collector.check("BRH-KEY-DELETE-COUNT", len(delete_occurrences) == 1,
                    delete_occurrences[0][0] if delete_occurrences else helper.path,
                    delete_occurrences[0][1] if delete_occurrences else 1,
                    "Keychain helper paths must contain exactly one SecItemDelete call")
    wipe_matches = definitions_for_selector(helper, "wipeKeychainForAccessGroups:itemClasses:error:")
    collector.check("BRH-KEY-DELETE-WIPE-ONLY",
                    len(wipe_matches) == 1 and wipe_matches[0].sanitized_body_text.count("SecItemDelete(") == 1,
                    helper.path, wipe_matches[0].signature_start_line if wipe_matches else 1,
                    "the sole SecItemDelete must remain inside explicit wipeKeychainForAccessGroups:itemClasses:error:")

    count_helper = unique_c_function(helper, "PXCountKeychainItemsMatchingQuery")
    count_helper_body = " ".join(count_helper.sanitized_body_text.split())
    collector.check("BRH-KEY-WIPE-COUNT-PREDICATE",
                    "NSMutableDictionary *countQuery = [baseQuery mutableCopy];" in count_helper_body and
                    count_helper_body.count("SecItemCopyMatching(") == 1 and
                    "kSecMatchLimitAll" in count_helper_body and
                    "kSecReturnAttributes" in count_helper_body,
                    helper.path, count_helper.signature_start_line,
                    "wipe count helper must derive count queries from the exact delete predicate")

    wipe_body = " ".join(wipe_matches[0].body_text.split()) if len(wipe_matches) == 1 else ""
    synchronizable_pair = (
        "(__bridge id)kSecAttrSynchronizable: "
        "(__bridge id)kSecAttrSynchronizableAny,"
    )
    collector.check("BRH-KEY-WIPE-SYNCHRONIZABLE-ANY",
                    len(wipe_matches) == 1 and wipe_body.count(synchronizable_pair) == 1,
                    helper.path, wipe_matches[0].signature_start_line if wipe_matches else 1,
                    "wipe delete predicate must include kSecAttrSynchronizableAny exactly once")

    verification_tokens = (
        "PXCountKeychainItemsMatchingQuery(query, &itemCount)",
        "SecItemDelete((__bridge CFDictionaryRef)query)",
        "PXCountKeychainItemsMatchingQuery(query, &residualCount)",
        "residualCount == 0",
        "if (verifiedEmpty)",
        "result.itemsSucceeded += itemCount",
    )
    verification_positions = identifier_positions(wipe_body, verification_tokens)
    collector.check("BRH-KEY-WIPE-POST-DELETE-VERIFY",
                    len(wipe_matches) == 1 and
                    wipe_body.count("PXCountKeychainItemsMatchingQuery(") == 2 and
                    positions_strictly_increasing(verification_positions) and
                    "result.itemsFailed += itemCount" in wipe_body and
                    "Keychain wipe left %lu residual" in wipe_body and
                    "Failed to verify %@ items" in wipe_body,
                    helper.path, wipe_matches[0].signature_start_line if wipe_matches else 1,
                    "wipe must verify the exact predicate is empty before reporting item success")

    process = unique_c_function(helper, "PXProcessRestoreItem")
    update = unique_c_function(helper, "PXUpdateExistingRestoreItem")
    required_process = ("SecItemAdd", "PXCreateRestoreIdentity", "PXCopyUniquePersistentReferenceForIdentity",
                        "PXCreateUpdateAttributesFromAddQuery", "PXUpdateExistingRestoreItem")
    collector.check("BRH-KEY-RESTORE-PROCESS", all(token in process.sanitized_body_text for token in required_process),
                    helper.path, process.signature_start_line,
                    "PXProcessRestoreItem must preserve add, exact identity, persistent-reference lookup and in-place update flow")
    collector.check("BRH-KEY-RESTORE-UPDATE", "SecItemUpdate(" in update.sanitized_body_text,
                    helper.path, update.signature_start_line,
                    "PXUpdateExistingRestoreItem must continue using SecItemUpdate")
    restore_methods = definitions_for_selector(helper, "restoreKeychainFromFile:overwrite:error:")
    restore_delete = any("SecItemDelete(" in method.sanitized_body_text for method in restore_methods)
    other_restore_delete = ("SecItemDelete(" in process.sanitized_body_text or
                            "SecItemDelete(" in update.sanitized_body_text or
                            "SecItemDelete(" in backup_helper.masked or
                            "SecItemDelete(" in manager.masked)
    collector.check("BRH-KEY-RESTORE-NO-DELETE", not restore_delete and not other_restore_delete,
                    helper.path, process.signature_start_line,
                    "Keychain Restore must never pre-delete or delete an existing item")
    wrapper_text = shell.text.lower()
    collector.check("BRH-KEY-WRAPPER-OVERWRITE",
                    "--overwrite" in wrapper_text and "update one exact existing item in place" in wrapper_text and "never delete" in wrapper_text,
                    shell.path, source_line_for_token(shell, "--overwrite   For restore"),
                    "Keychain wrapper help must describe exact in-place overwrite and never-delete semantics")


def guard_ui(sources: Mapping[str, SourceFile], collector: GuardCollector) -> None:
    ui = sources["AppDataBackupRestoreViewController.m"]
    backup_enum = {name: evaluate_integer_expression(value)
                   for name, value in extract_enum_assignments(ui, "PXBackupAlertOutcome").items()}
    restore_enum = {name: evaluate_integer_expression(value)
                    for name, value in extract_enum_assignments(ui, "PXRestoreAlertOutcome").items()}
    expected_backup_enum = {
        "PXBackupAlertOutcomeSuccessful": 1,
        "PXBackupAlertOutcomeCompletedWithWarnings": 2,
        "PXBackupAlertOutcomeFailed": 3,
    }
    expected_restore_enum = {
        "PXRestoreAlertOutcomeSuccessful": 1,
        "PXRestoreAlertOutcomeCompletedWithWarnings": 2,
        "PXRestoreAlertOutcomeCompletedWithComponentFailures": 3,
        "PXRestoreAlertOutcomeFailed": 4,
        "PXRestoreAlertOutcomeFailedWithCompletedRollback": 5,
        "PXRestoreAlertOutcomeFailedWithIncompleteRollback": 6,
    }
    collector.check("BRH-UI-BACKUP-OUTCOMES", backup_enum == expected_backup_enum, ui.path, 1,
                    "Backup outcome enum differs from the exact three-value contract")
    collector.check("BRH-UI-RESTORE-OUTCOMES", restore_enum == expected_restore_enum, ui.path, 1,
                    "Restore outcome enum differs from the exact six-value contract")
    backup_classifier = unique_c_function(ui, "PXBackupAlertOutcomeForResult")
    backup_order = identifier_positions(backup_classifier.sanitized_body_text,
                                        ("error != nil", "!PXBackupResultIsValidForPresentation", "result.warnings.count > 0", "PXBackupAlertOutcomeSuccessful"))
    collector.check("BRH-UI-BACKUP-PRECEDENCE", positions_strictly_increasing(backup_order), ui.path,
                    backup_classifier.signature_start_line,
                    "Backup classifier precedence must remain error, invalid result, warnings, success")
    backup_titles = set(literal_values_in_range(ui, unique_c_function(ui, "PXBackupAlertTitleForOutcome").body_start,
                                                unique_c_function(ui, "PXBackupAlertTitleForOutcome").body_end))
    collector.check("BRH-UI-BACKUP-TITLES", backup_titles == {"Backup Successful", "Backup Completed with Warnings", "Backup Failed"},
                    ui.path, source_line_for_token(ui, "Backup Successful"),
                    "Backup alert titles differ from the exact accepted set")
    restore_classifier = unique_c_function(ui, "PXRestoreAlertOutcomeForResult")
    restore_order = identifier_positions(restore_classifier.sanitized_body_text,
                                         ("PXRestoreResultHasIncompleteRollback", "PXRestoreResultHasCompletedRollback",
                                          "error != nil", "!validResult", "result.hasFailures", "result.hasWarnings"))
    collector.check("BRH-UI-RESTORE-PRECEDENCE", positions_strictly_increasing(restore_order), ui.path,
                    restore_classifier.signature_start_line,
                    "Restore classifier precedence must preserve rollback, error, validity, component failure and warning order")
    restore_title_function = unique_c_function(ui, "PXRestoreAlertTitleForOutcome")
    restore_titles = set(literal_values_in_range(ui, restore_title_function.body_start, restore_title_function.body_end))
    expected_restore_titles = {
        "Restore Successful", "Restore Completed with Warnings", "Restore Completed with Component Failures",
        "Restore Failed", "Restore Failed: Component Rollback Completed", "Restore Failed: Rollback Incomplete",
    }
    collector.check("BRH-UI-RESTORE-TITLES", restore_titles == expected_restore_titles, ui.path,
                    restore_title_function.signature_start_line,
                    "Restore alert titles differ from the exact accepted set")
    collector.check("BRH-UI-COMPONENT-HEADER", "Component Results:" in (literal.value for literal in ui.literals),
                    ui.path, source_line_for_token(ui, "Component Results:"),
                    "Restore component-results section header is missing")

    methods = method_records(ui)
    backup_button = [method for method in methods if method.selector == "backupButtonTapped" and method.is_definition]
    restore_button = [method for method in methods if method.selector == "restoreButtonTapped" and method.is_definition]
    collector.check("BRH-UI-BACKUP-CALLBACK", len(backup_button) == 1 and
                    backup_button[0].sanitized_body_text.count("_presentResultAlertBestEffortWithTitle:") == 1 and
                    "copyPath = result.backupDirectory;" in backup_button[0].sanitized_body_text,
                    ui.path, backup_button[0].signature_start_line if backup_button else 1,
                    "Backup callback must present exactly once and expose copyPath only from a valid result")
    if len(restore_button) == 1:
        body = restore_button[0].sanitized_body_text
        callback_order = identifier_positions(body, ("PXRestoreComponentResultsSection", "PXAppendRestoreWarnings",
                                                     "_presentResultAlertBestEffortWithTitle:"))
        collector.check("BRH-UI-RESTORE-CALLBACK",
                        positions_strictly_increasing(callback_order) and body.count("_presentResultAlertBestEffortWithTitle:") == 1 and
                        "copyPath:nil" in body,
                        ui.path, restore_button[0].signature_start_line,
                        "Restore callback must append components, append aggregate warnings, present once and use copyPath:nil")
    else:
        collector.check("BRH-UI-RESTORE-CALLBACK", False, ui.path, 1, "cannot verify Restore callback")

    advanced_enum = {name: evaluate_integer_expression(value)
                     for name, value in extract_enum_assignments(ui, "PXAdvancedDataScope").items()}
    expected_advanced = {
        "PXAdvancedDataScopeAppGroups": 1 << 0,
        "PXAdvancedDataScopePreferences": 1 << 1,
        "PXAdvancedDataScopeKeychain": 1 << 2,
        "PXAdvancedDataScopeProfileAppData": 1 << 3,
        "PXAdvancedDataScopeGlobalSafari": 1 << 4,
        "PXAdvancedDataScopeSystemGlobal": 1 << 5,
        "PXAdvancedDataScopeSharedSystemDatabases": 1 << 6,
    }
    collector.check("BRH-UI-ADVANCED-SCOPES", advanced_enum == expected_advanced, ui.path, 1,
                    "advanced Backup/Restore scope enum differs from the exact seven-bit contract")
    expected_order = (
        "PXAdvancedDataScopeProfileAppData", "PXAdvancedDataScopeGlobalSafari", "PXAdvancedDataScopeAppGroups",
        "PXAdvancedDataScopeSystemGlobal", "PXAdvancedDataScopeSharedSystemDatabases",
        "PXAdvancedDataScopePreferences", "PXAdvancedDataScopeKeychain",
    )
    collector.check("BRH-UI-ADVANCED-ORDER",
                    operand_set(ui, "PXAdvancedDataScopePresentationOrder", "PXAdvancedDataScope") == expected_order,
                    ui.path, source_line_for_token(ui, "PXAdvancedDataScopePresentationOrder"),
                    "advanced scope presentation order differs from the accepted seven-scope order")
    display_function = unique_c_function(ui, "PXAdvancedDataScopeDisplayName")
    display_literals = set(literal_values_in_range(ui, display_function.body_start, display_function.body_end))
    collector.check("BRH-UI-ADVANCED-NAMES", display_literals == {
        "Profile App Data", "Global Safari", "App Groups", "System Global",
        "Shared System Databases", "Global Preferences", "Keychain",
    }, ui.path, display_function.signature_start_line,
                    "advanced scope display names differ from the accepted set")
    all_literals = set(literal.value for literal in ui.literals)
    required_confirmation = {
        "Confirm Backup", "Confirm Advanced Backup", "Backup", "Back Up Advanced Data",
        "Confirm Restore", "Confirm Advanced Restore", "Restore", "Restore Advanced Data",
    }
    collector.check("BRH-UI-CONFIRMATION-TEXT", required_confirmation.issubset(all_literals), ui.path, 1,
                    "Backup/Restore confirmation titles or action labels are missing")
    collector.check("BRH-UI-CONFIRMATION-STYLES",
                    "style:UIAlertActionStyleDefault" in ui.masked and "style:UIAlertActionStyleDestructive" in ui.masked,
                    ui.path, 1, "Backup must use default confirmation style and Restore must use destructive style")
    warning_values = "\n".join(literal.value.lower() for literal in ui.literals)
    collector.check("BRH-UI-CONFIRMATION-WARNINGS",
                    all(phrase in warning_values for phrase in (
                        "shared or sensitive data", "affect other apps or system services", "cannot be undone")),
                    ui.path, 1, "advanced Restore warning lost shared-data, cross-app or irreversible-operation wording")
    collector.check("BRH-UI-CFBOOLEAN",
                    ui.masked.count("CFBooleanGetTypeID()") >= 2 and ui.masked.count("CFGetTypeID(") >= 2,
                    ui.path, source_line_for_token(ui, "PXReadExactManifestBoolean"),
                    "manifest confirmation booleans must retain exact CFBoolean type validation")

    if len(restore_button) == 1:
        body = restore_button[0].sanitized_body_text
        binding_tokens = (
            "selectedManifest", "PXAdvancedDataScopesForValidatedManifest(selectedManifest",
            "PXImmutableManifestConfirmationSnapshot(selectedManifest)", "confirmAlert",
            "currentManifest", "PXAdvancedDataScopesForValidatedManifest(currentManifest",
            "[currentManifest isEqual:confirmedManifestSnapshot]", "currentScopes == confirmedScopes",
            "processingAlert", "restoreBackupAtDirectory:",
        )
        collector.check("BRH-UI-MANIFEST-ORDER", positions_strictly_increasing(identifier_positions(body, binding_tokens)),
                        ui.path, restore_button[0].signature_start_line,
                        "Restore confirmation must validate, snapshot, confirm, re-read, compare and only then process")
        collector.check("BRH-UI-MANIFEST-EQUALITY", "[currentManifest isEqual:confirmedManifestSnapshot]" in body,
                        ui.path, restore_button[0].signature_start_line,
                        "Restore destructive action must compare the whole current manifest to the confirmed snapshot")
        collector.check("BRH-UI-SCOPE-EQUALITY", "currentScopes == confirmedScopes" in body,
                        ui.path, restore_button[0].signature_start_line,
                        "Restore destructive action must compare current and confirmed advanced scopes")
    else:
        collector.check("BRH-UI-MANIFEST-ORDER", False, ui.path, 1, "cannot verify manifest binding order")
        collector.check("BRH-UI-MANIFEST-EQUALITY", False, ui.path, 1, "cannot verify whole-manifest equality")
        collector.check("BRH-UI-SCOPE-EQUALITY", False, ui.path, 1, "cannot verify scope equality")


def expected_workflow_block(newline: str = "\r\n") -> str:
    return newline.join((
        "      - name: Audit backup/restore hardening invariants",
        "        run: |",
        "          python3 scripts/audit_backup_restore_hardening.py --self-test",
        "          python3 scripts/audit_backup_restore_hardening.py",
        "",
    ))


def workflow_with_audit(text: str) -> str:
    if "Audit backup/restore hardening invariants" in text:
        return text
    newline = "\r\n" if "\r\n" in text else "\n"
    checkout = ("      - name: Checkout" + newline +
                "        uses: actions/checkout@v4" + newline + newline)
    if checkout not in text:
        raise AuditInternalError("workflow Checkout block not found")
    return text.replace(checkout, checkout + expected_workflow_block(newline), 1)


def guard_workflow(sources: Mapping[str, SourceFile], collector: GuardCollector) -> None:
    workflow = sources[".github/workflows/build-ios-arm.yml"]
    block = expected_workflow_block("\r\n" if "\r\n" in workflow.text else "\n")
    collector.check("BRH-WF-AUDIT-BLOCK", workflow.text.count(block) == 1, workflow.path, 1,
                    "workflow must contain exactly one canonical hardening audit step")
    self_pos = workflow.text.find("python3 scripts/audit_backup_restore_hardening.py --self-test")
    audit_pos = workflow.text.find("python3 scripts/audit_backup_restore_hardening.py", self_pos + 1)
    install_pos = workflow.text.find("- name: Install build dependencies")
    checkout_pos = workflow.text.find("- name: Checkout")
    collector.check("BRH-WF-AUDIT-COMMANDS", self_pos >= 0 and audit_pos > self_pos,
                    workflow.path, line_number(workflow.text, max(0, self_pos)),
                    "workflow must run self-test before repository audit")
    collector.check("BRH-WF-AUDIT-ORDER",
                    checkout_pos >= 0 and self_pos > checkout_pos and install_pos > audit_pos,
                    workflow.path, line_number(workflow.text, max(0, self_pos)),
                    "hardening audit must run immediately after Checkout and before dependency installation")
    forbidden = ("continue-on-error", "|| true", "allow-failure")
    block_start = workflow.text.find("Audit backup/restore hardening invariants")
    block_end = workflow.text.find("- name: Install build dependencies", block_start)
    audit_block = workflow.text[block_start:block_end] if block_start >= 0 and block_end >= 0 else ""
    collector.check("BRH-WF-NO-BYPASS", not any(token in audit_block for token in forbidden),
                    workflow.path, line_number(workflow.text, max(0, block_start)),
                    "workflow audit step must not permit continue-on-error or shell bypass")


def run_repository_guards(sources: Mapping[str, SourceFile], collector: GuardCollector) -> None:
    guard_public_and_removed_api(sources, collector)
    guard_quarantine(sources, collector)
    guard_aliases(sources, collector)
    guard_clear(sources, collector)
    guard_permissions(sources, collector)
    guard_manifest(sources, collector)
    guard_keychain(sources, collector)
    guard_ui(sources, collector)
    guard_workflow(sources, collector)


def audit_repository(root: Path) -> GuardCollector:
    collector = GuardCollector()
    sources = load_repository_sources(root, collector)
    run_repository_guards(sources, collector)
    collector.check("BRH-ENV-GUARD-FLOOR", collector.total + 1 >= MINIMUM_REPOSITORY_GUARDS,
                    "scripts/audit_backup_restore_hardening.py", 1,
                    f"repository guard count is below {MINIMUM_REPOSITORY_GUARDS}")
    return collector


def run_one_group(group: str, sources: Mapping[str, SourceFile]) -> GuardCollector:
    collector = GuardCollector()
    groups = {
        "API": guard_public_and_removed_api,
        "QTN": guard_quarantine,
        "ALS": guard_aliases,
        "CLR": guard_clear,
        "PERM": guard_permissions,
        "MAN": guard_manifest,
        "KEY": guard_keychain,
        "UI": guard_ui,
        "WF": guard_workflow,
    }
    groups[group](sources, collector)
    return collector


def expect_mutation_guard(name: str, group: str, sources: Mapping[str, SourceFile], expected_guard: str) -> None:
    collector = run_one_group(group, sources)
    failed = {violation.guard_id for violation in collector.violations}
    if expected_guard not in failed:
        raise AuditInternalError(f"negative mutation {name} did not trigger {expected_guard}; got {sorted(failed)}")


def method_replacement(source: SourceFile, selector: str, transform: callable) -> str:
    matches = definitions_for_selector(source, selector)
    if len(matches) != 1:
        raise AuditInternalError(f"mutation requires one definition for {selector}")
    method = matches[0]
    replacement = transform(source.text[method.signature_start:method.body_end or method.signature_end])
    return source.text[:method.signature_start] + replacement + source.text[method.body_end or method.signature_end:]


def self_test_sources(root: Path) -> Dict[str, SourceFile]:
    sources = load_repository_sources(root)
    workflow = sources[".github/workflows/build-ios-arm.yml"]
    sources[workflow.path] = source_from_text(workflow.path, workflow_with_audit(workflow.text))
    return sources


def run_negative_mutation_tests(root: Path) -> Tuple[int, int]:
    base = self_test_sources(root)
    tests: List[Tuple[str, str, Mapping[str, SourceFile], str]] = []

    header = base["AppDataCleaner.h"]
    header_newline = source_newline(header)
    insert_point = header.text.rfind("@end")
    tests.append(("task61-public", "API",
                  replace_source_text(base, header.path, header.text[:insert_point] + f"- (void)performFullCleanup:(NSString *)bundleID;{header_newline}" + header.text[insert_point:]),
                  "BRH-API-REMOVED-PUBLIC-PERFORMFULLCLEANUP"))
    tests.append(("task62-public", "API",
                  replace_source_text(base, header.path, header.text[:insert_point] + f"- (void)clearAppData:(NSString *)bundleID;{header_newline}" + header.text[insert_point:]),
                  "BRH-API-REMOVED-PUBLIC-CLEARAPPDATA"))

    cleaner = base["AppDataCleaner.m"]
    cleaner_newline = source_newline(cleaner)
    private_line = f"- (void)performFullCleanup:(NSString *)bundleID;{cleaner_newline}"
    tests.append(("private-declaration", "API",
                  replace_source_text(base, cleaner.path, cleaner.text.replace(private_line, "", 1)),
                  "BRH-API-REMOVED-PRIVATE-PERFORMFULLCLEANUP"))
    method = definitions_for_selector(cleaner, "performFullCleanup:")[0]
    tests.append(("runtime-implementation", "API",
                  replace_source_text(base, cleaner.path, remove_range(cleaner.text, method.signature_start, method.body_end or method.signature_end)),
                  "BRH-API-REMOVED-IMPL-PERFORMFULLCLEANUP"))
    external_direct = dict(base)
    external_direct["Mutation.m"] = source_from_text("Mutation.m", "void f(id x,id y){ [x clearAppData:y]; }\n")
    tests.append(("external-direct", "API", external_direct, "BRH-API-REMOVED-EXTERNAL-CLEARAPPDATA"))
    external_dynamic = dict(base)
    external_dynamic["Mutation.m"] = source_from_text("Mutation.m", 'void f(void){ NSSelectorFromString(@"clearAppData:"); }\n')
    tests.append(("external-dynamic", "API", external_dynamic, "BRH-API-REMOVED-EXTERNAL-CLEARAPPDATA"))

    qtn_mutated = method_replacement(cleaner, "performFullCleanup:",
                                     lambda text: text.replace("PXLogQuarantinedLegacyClearSelector(_cmd);",
                                                               f"[[NSFileManager defaultManager] removeItemAtPath:bundleID error:nil];{cleaner_newline}    PXLogQuarantinedLegacyClearSelector(_cmd);"))
    tests.append(("quarantine-filesystem", "QTN", replace_source_text(base, cleaner.path, qtn_mutated),
                  "BRH-QTN-SHAPE-PERFORMFULLCLEANUP"))
    secure_mutated = method_replacement(cleaner, "securelyWipeFile:", lambda text: text.replace("return NO;", "return YES;"))
    tests.append(("secure-return", "QTN", replace_source_text(base, cleaner.path, secure_mutated),
                  "BRH-QTN-SECURE-RETURN"))
    logger_mutated = cleaner.text.replace("NSStringFromSelector(selector));",
                                          f"NSStringFromSelector(selector));{cleaner_newline}    NSLog(@\"%@\", bundleID);", 1)
    tests.append(("logger-privacy", "QTN", replace_source_text(base, cleaner.path, logger_mutated),
                  "BRH-QTN-LOGGER-PRIVACY"))

    wrong_alias = method_replacement(cleaner, "clearAppData:",
                                     lambda text: text.replace("[self completeAppDataWipe:bundleID];",
                                                               "[self clearSystemLogs:bundleID];"))
    tests.append(("alias-wrong-target", "ALS", replace_source_text(base, cleaner.path, wrong_alias),
                  "BRH-ALS-MAP-CLEARAPPDATA"))
    second_send = method_replacement(cleaner, "clearAppData:",
                                     lambda text: text.replace("[self completeAppDataWipe:bundleID];",
                                                               f"[self completeAppDataWipe:bundleID];{cleaner_newline}    [self clearSystemLogs:bundleID];"))
    tests.append(("alias-second-send", "ALS", replace_source_text(base, cleaner.path, second_send),
                  "BRH-ALS-SINGLE-CLEARAPPDATA"))

    data_mask = cleaner.text.replace(
        f"    PXClearScopePluginKitData;{cleaner_newline}{cleaner_newline}static const PXClearScope PXMigratedFullClearScopes",
        f"    PXClearScopePluginKitData |{cleaner_newline}    PXClearScopeKeychain;{cleaner_newline}{cleaner_newline}static const PXClearScope PXMigratedFullClearScopes",
        1,
    )
    tests.append(("data-mask-keychain", "CLR", replace_source_text(base, cleaner.path, data_mask),
                  "BRH-CLR-DATA-MASK"))
    full_mask = cleaner.text.replace(
        f"    PXClearScopePluginKitData |{cleaner_newline}    PXClearScopeKeychain;",
        "    PXClearScopePluginKitData;",
        1,
    )
    tests.append(("full-mask-no-keychain", "CLR", replace_source_text(base, cleaner.path, full_mask),
                  "BRH-CLR-FULL-MASK"))
    precedence = cleaner.text.replace(
        f"@(PXClearScopeApplicationData),{cleaner_newline}                    @(PXClearScopeExtensionData)",
        f"@(PXClearScopeExtensionData),{cleaner_newline}                    @(PXClearScopeApplicationData)",
        1,
    )
    tests.append(("failure-precedence", "CLR", replace_source_text(base, cleaner.path, precedence),
                  "BRH-CLR-FAILURE-PRECEDENCE"))

    chmod_mutation = cleaner.text + f'{cleaner_newline}static NSString *PXMutation = @"chmod -R 777 /tmp/x";{cleaner_newline}'
    tests.append(("chmod-recursive", "PERM", replace_source_text(base, cleaner.path, chmod_mutation),
                  "BRH-PERM-CHMOD-RECURSIVE"))
    marker_mutation = cleaner.text + f'{cleaner_newline}static NSString *PXMarkerMutation = @"touch /tmp/.initialized";{cleaner_newline}'
    tests.append(("marker-touch", "PERM", replace_source_text(base, cleaner.path, marker_mutation),
                  "BRH-PERM-MARKER-TOUCH"))

    manager = base["AppDataBackupManager.m"]
    manager_v5 = manager.text.replace("value == 2 || value == 3 || value == 4",
                                      "value == 2 || value == 3 || value == 4 || value == 5", 1)
    tests.append(("manager-version-five", "MAN", replace_source_text(base, manager.path, manager_v5),
                  "BRH-MAN-MANAGER-VERSIONS"))
    v4 = base["PXBackupManifestV4.m"]
    digest_mutation = v4.text.replace('@"sha256"', '@"sha1"', 1)
    tests.append(("v4-digest", "MAN", replace_source_text(base, v4.path, digest_mutation),
                  "BRH-MAN-V4-DIGEST"))

    shell = base["scripts/keychain_backup.sh"]
    shell_exit = shell.text.replace("readonly PX_KEYCHAIN_EXIT_PARTIAL=10", "readonly PX_KEYCHAIN_EXIT_PARTIAL=11", 1)
    tests.append(("shell-exit-code", "KEY", replace_source_text(base, shell.path, shell_exit),
                  "BRH-KEY-EXIT-PARITY"))

    direct_helper = base["KeychainHelper/backup_helper.m"]
    helper_contract_mutation = direct_helper.text.replace(
        'NSString *requestedCSV = args[@"requested-groups"];',
        'NSString *requestedCSV = args[@"groups"];',
        1,
    )
    tests.append(("helper-cli-contract", "KEY",
                  replace_source_text(base, direct_helper.path, helper_contract_mutation),
                  "BRH-KEY-CLI-METADATA-CONTRACT"))

    clear_wipe_selector = (
        "_executeKeychainWipeForBundleIdentifier:selectedGroups:"
        "applicationIdentifier:systemApplication:error:"
    )
    clear_cli_mutation = method_replacement(
        cleaner,
        clear_wipe_selector,
        lambda text: text.replace('@"--requested-groups", groupsCSV,', "", 1),
    )
    tests.append(("clear-helper-cli-metadata", "KEY",
                  replace_source_text(base, cleaner.path, clear_cli_mutation),
                  "BRH-KEY-CLEAR-CLI-METADATA"))

    helper = base["KeychainHelper/KeychainBackupHelper.m"]
    helper_newline = source_newline(helper)
    wipe_selector = "wipeKeychainForAccessGroups:itemClasses:error:"
    synchronizable_mutation = method_replacement(
        helper,
        wipe_selector,
        lambda text: text.replace(
            "(__bridge id)kSecAttrSynchronizable: (__bridge id)kSecAttrSynchronizableAny,",
            "",
            1,
        ),
    )
    tests.append(("wipe-synchronizable-any", "KEY",
                  replace_source_text(base, helper.path, synchronizable_mutation),
                  "BRH-KEY-WIPE-SYNCHRONIZABLE-ANY"))

    verification_mutation = method_replacement(
        helper,
        wipe_selector,
        lambda text: text.replace(
            "OSStatus verificationStatus = PXCountKeychainItemsMatchingQuery(query, &residualCount);",
            "OSStatus verificationStatus = errSecSuccess;",
            1,
        ),
    )
    tests.append(("wipe-post-delete-verification", "KEY",
                  replace_source_text(base, helper.path, verification_mutation),
                  "BRH-KEY-WIPE-POST-DELETE-VERIFY"))

    delete_mutation = helper.text.replace("OSStatus addStatus = SecItemAdd((__bridge CFDictionaryRef)addQuery, NULL);",
                                          f"SecItemDelete((__bridge CFDictionaryRef)addQuery);{helper_newline}        OSStatus addStatus = SecItemAdd((__bridge CFDictionaryRef)addQuery, NULL);", 1)
    tests.append(("restore-delete", "KEY", replace_source_text(base, helper.path, delete_mutation),
                  "BRH-KEY-RESTORE-NO-DELETE"))

    ui = base["AppDataBackupRestoreViewController.m"]
    title_mutation = ui.text.replace('@"Restore Successful"', '@"Restore Complete"', 1)
    tests.append(("restore-title", "UI", replace_source_text(base, ui.path, title_mutation),
                  "BRH-UI-RESTORE-TITLES"))
    header_mutation = ui.text.replace('@"Component Results:"', '@"Results:"', 1)
    tests.append(("component-header", "UI", replace_source_text(base, ui.path, header_mutation),
                  "BRH-UI-COMPONENT-HEADER"))
    equality_mutation = ui.text.replace("[currentManifest isEqual:confirmedManifestSnapshot] &&", "YES &&", 1)
    tests.append(("manifest-equality", "UI", replace_source_text(base, ui.path, equality_mutation),
                  "BRH-UI-MANIFEST-EQUALITY"))

    workflow = base[".github/workflows/build-ios-arm.yml"]
    workflow_mutation = workflow.text.replace("          python3 scripts/audit_backup_restore_hardening.py\r\n", "", 1)
    if workflow_mutation == workflow.text:
        workflow_mutation = workflow.text.replace("          python3 scripts/audit_backup_restore_hardening.py\n", "", 1)
    tests.append(("workflow-command", "WF", replace_source_text(base, workflow.path, workflow_mutation),
                  "BRH-WF-AUDIT-COMMANDS"))

    passed = 0
    for name, group, sources, expected in tests:
        expect_mutation_guard(name, group, sources, expected)
        passed += 1
    return passed, len(tests)


def run_all_self_tests(root: Path) -> Tuple[int, int]:
    parser_passed, parser_total = run_parser_self_tests()
    mutation_passed, mutation_total = run_negative_mutation_tests(root)
    passed = parser_passed + mutation_passed
    total = parser_total + mutation_total
    if total < MINIMUM_SELF_TESTS:
        raise AuditInternalError(f"self-test count {total} is below {MINIMUM_SELF_TESTS}")
    return passed, total


def usage_error(message: str) -> int:
    print(f"backup_restore_hardening: {message}; usage: audit_backup_restore_hardening.py [--self-test]", file=sys.stderr)
    return 2


def main(argv: Sequence[str]) -> int:
    if any(arg not in ("--self-test",) for arg in argv) or len(argv) > 1:
        return usage_error("unknown or invalid argument")
    root = Path(__file__).resolve().parents[1]
    try:
        if argv == ["--self-test"]:
            passed, total = run_all_self_tests(root)
            print(f"backup_restore_hardening self-test: PASS ({passed}/{total})")
            return 0
        collector = audit_repository(root)
        if collector.violations:
            violations = sorted(collector.violations)
            print(
                f"backup_restore_hardening audit: FAIL "
                f"({len(violations)} failed, {collector.passed} passed)"
            )
            for violation in violations:
                print(
                    f"[{violation.guard_id}] {violation.path}:{violation.line}: "
                    f"{violation.message}"
                )
            return 1
        print(f"backup_restore_hardening audit: PASS ({collector.passed}/{collector.total})")
        return 0
    except AuditInternalError as exc:
        print(f"backup_restore_hardening: internal error: {exc}", file=sys.stderr)
        return 2
    except Exception as exc:
        if DEBUG_TRACEBACK:
            raise
        print(f"backup_restore_hardening: internal error: {type(exc).__name__}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
