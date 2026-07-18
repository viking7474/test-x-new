#!/usr/bin/env python3
"""Deterministic malicious archive fixture generator for PXBackupArchiveValidator."""

from __future__ import annotations

import binascii
import hashlib
import json
import os
from pathlib import Path
import shutil
import stat
import struct
import sys
import tempfile
from typing import Callable, Dict, Iterable, List, Mapping, Optional, Sequence, Tuple


BLOCK = 512
ACCEPTED_COUNT = 20
REJECTED_COUNT = 66
FIXTURE_COUNT = ACCEPTED_COUNT + REJECTED_COUNT
SCHEMA_VERSION = 1

ERROR_DISTRIBUTION = {
    5: 3,
    6: 6,
    7: 9,
    8: 10,
    9: 5,
    10: 11,
    11: 15,
    12: 5,
    13: 1,
    14: 1,
}

ERROR_NAMES = {
    5: "UnsupportedCompression",
    6: "TruncatedArchive",
    7: "InvalidHeader",
    8: "UnsafeEntryPath",
    9: "DuplicateEntry",
    10: "UnsupportedEntryType",
    11: "InvalidExtendedHeader",
    12: "LimitExceeded",
    13: "SizeMismatch",
    14: "DigestMismatch",
}


class FixtureError(Exception):
    pass


class TestCounter:
    def __init__(self) -> None:
        self.passed = 0
        self.total = 0

    def check(self, condition: bool, name: str) -> None:
        self.total += 1
        if not condition:
            raise FixtureError(f"self-test failed: {name}")
        self.passed += 1

    def equal(self, actual: object, expected: object, name: str) -> None:
        self.check(actual == expected, name)


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def octal_field(value: int, width: int) -> bytes:
    if not isinstance(value, int) or value < 0 or width < 2:
        raise FixtureError("invalid octal field request")
    digits = format(value, "o").encode("ascii")
    if len(digits) > width - 1:
        raise FixtureError("octal field overflow")
    return b"0" * (width - 1 - len(digits)) + digits + b"\0"


def base256_field(value: int, width: int) -> bytes:
    if not isinstance(value, int) or value < 0 or width < 2:
        raise FixtureError("invalid base-256 field request")
    if value >= 1 << (width * 8 - 2):
        raise FixtureError("base-256 field overflow")
    raw = bytearray(value.to_bytes(width, "big"))
    raw[0] |= 0x80
    return bytes(raw)


def invalid_negative_base256(width: int) -> bytes:
    if width < 2:
        raise FixtureError("invalid negative base-256 width")
    return bytes([0xC0]) + b"\0" * (width - 1)


def checksum_field(value: int) -> bytes:
    digits = format(value, "o").encode("ascii")
    if len(digits) > 6:
        raise FixtureError("checksum overflow")
    return b"0" * (6 - len(digits)) + digits + b"\0 "


def _copy_field(block: bytearray, offset: int, width: int, value: bytes, name: str) -> None:
    if len(value) > width:
        raise FixtureError(f"{name} exceeds field width")
    block[offset : offset + len(value)] = value


def tar_header(
    *,
    name: bytes,
    prefix: bytes = b"",
    mode: int = 0o644,
    uid: int = 0,
    gid: int = 0,
    size: int = 0,
    size_field: Optional[bytes] = None,
    mtime: int = 0,
    typeflag: bytes = b"0",
    linkname: bytes = b"",
    magic: bytes = b"ustar\0",
    version: bytes = b"00",
    checksum_mode: str = "unsigned",
    old_prefix_bytes: bytes = b"",
    mode_field: Optional[bytes] = None,
) -> bytes:
    if len(typeflag) != 1:
        raise FixtureError("type flag must be one byte")
    if len(magic) != 6 or len(version) != 2:
        raise FixtureError("tar magic/version width is invalid")
    block = bytearray(BLOCK)
    _copy_field(block, 0, 100, name, "name")
    block[100:108] = mode_field if mode_field is not None else octal_field(mode, 8)
    block[108:116] = octal_field(uid, 8)
    block[116:124] = octal_field(gid, 8)
    block[124:136] = size_field if size_field is not None else octal_field(size, 12)
    block[136:148] = octal_field(mtime, 12)
    block[148:156] = b" " * 8
    block[156:157] = typeflag
    _copy_field(block, 157, 100, linkname, "link name")
    block[257:263] = magic
    block[263:265] = version
    _copy_field(block, 345, 155, prefix, "prefix")
    if old_prefix_bytes:
        _copy_field(block, 345, 155, old_prefix_bytes, "old prefix")
    unsigned_sum = sum(block)
    signed_sum = sum(byte if byte < 128 else byte - 256 for byte in block)
    if checksum_mode == "unsigned":
        stored = unsigned_sum
    elif checksum_mode == "signed":
        if signed_sum < 0:
            raise FixtureError("historical signed checksum is negative")
        stored = signed_sum
    elif checksum_mode == "invalid":
        stored = unsigned_sum + 1
    else:
        raise FixtureError("unknown checksum mode")
    block[148:156] = checksum_field(stored)
    return bytes(block)


def legacy_header(**kwargs: object) -> bytes:
    return tar_header(magic=b"\0" * 6, version=b"\0" * 2, **kwargs)


def posix_header(**kwargs: object) -> bytes:
    return tar_header(magic=b"ustar\0", version=b"00", **kwargs)


def gnu_header(**kwargs: object) -> bytes:
    return tar_header(magic=b"ustar ", version=b" \0", **kwargs)


def payload_padding(length: int, byte: int = 0) -> bytes:
    if length < 0 or not 0 <= byte <= 255:
        raise FixtureError("invalid payload padding request")
    amount = (-length) % BLOCK
    return bytes([byte]) * amount


def member(header: bytes, payload: bytes = b"", padding_byte: int = 0) -> bytes:
    if len(header) != BLOCK:
        raise FixtureError("tar header must be 512 bytes")
    return header + payload + payload_padding(len(payload), padding_byte)


def end_marker(extra_zero_blocks: int = 0) -> bytes:
    if extra_zero_blocks < 0:
        raise FixtureError("invalid end marker request")
    return b"\0" * BLOCK * (2 + extra_zero_blocks)


def pax_record(key: bytes, value: bytes) -> bytes:
    if not key or b"=" in key or b"\0" in key or b"\n" in key:
        raise FixtureError("invalid PAX key request")
    body = key + b"=" + value + b"\n"
    prefix_length = 1
    while True:
        total = prefix_length + 1 + len(body)
        rendered = str(total).encode("ascii")
        if len(rendered) == prefix_length:
            return rendered + b" " + body
        prefix_length = len(rendered)


def pax_raw_content(content_after_space: bytes) -> bytes:
    prefix_length = 1
    while True:
        total = prefix_length + 1 + len(content_after_space)
        rendered = str(total).encode("ascii")
        if len(rendered) == prefix_length:
            return rendered + b" " + content_after_space
        prefix_length = len(rendered)


def metadata_member(typeflag: bytes, payload: bytes, name: bytes = b"PaxHeader") -> bytes:
    header = posix_header(name=name, size=len(payload), typeflag=typeflag)
    return member(header, payload)


def pax_then_member(payload: bytes, real_header: bytes, real_payload: bytes = b"") -> bytes:
    return metadata_member(b"x", payload) + member(real_header, real_payload)


def gnu_long_then_member(typeflag: bytes, long_value: bytes, real_header: bytes) -> bytes:
    metadata_payload = long_value + b"\0"
    return metadata_member(typeflag, metadata_payload, name=b"././@LongLink") + member(real_header)


def deflate_stored(data: bytes) -> bytes:
    output = bytearray()
    if not data:
        return b"\x01\x00\x00\xff\xff"
    offset = 0
    while offset < len(data):
        chunk = data[offset : offset + 65535]
        offset += len(chunk)
        final = 1 if offset == len(data) else 0
        output.append(final)
        output.extend(struct.pack("<H", len(chunk)))
        output.extend(struct.pack("<H", 0xFFFF ^ len(chunk)))
        output.extend(chunk)
    return bytes(output)


def gzip_stored(data: bytes) -> bytes:
    header = b"\x1f\x8b\x08\x00\x00\x00\x00\x00\x00\xff"
    trailer = struct.pack("<II", binascii.crc32(data) & 0xFFFFFFFF, len(data) & 0xFFFFFFFF)
    return header + deflate_stored(data) + trailer


def parse_stored_gzip(data: bytes) -> bytes:
    if len(data) < 18 or data[:10] != b"\x1f\x8b\x08\x00\x00\x00\x00\x00\x00\xff":
        raise FixtureError("stored gzip header mismatch")
    offset = 10
    output = bytearray()
    final = False
    while not final:
        if offset + 5 > len(data) - 8:
            raise FixtureError("stored block is truncated")
        descriptor = data[offset]
        offset += 1
        final = bool(descriptor & 1)
        if descriptor & 0x06:
            raise FixtureError("stored block type mismatch")
        length, complement = struct.unpack_from("<HH", data, offset)
        offset += 4
        if complement != (0xFFFF ^ length):
            raise FixtureError("stored block complement mismatch")
        if offset + length > len(data) - 8:
            raise FixtureError("stored block payload is truncated")
        output.extend(data[offset : offset + length])
        offset += length
    if offset != len(data) - 8:
        raise FixtureError("stored gzip contains trailing bytes")
    crc, size = struct.unpack_from("<II", data, offset)
    if crc != (binascii.crc32(output) & 0xFFFFFFFF):
        raise FixtureError("stored gzip CRC mismatch")
    if size != (len(output) & 0xFFFFFFFF):
        raise FixtureError("stored gzip ISIZE mismatch")
    return bytes(output)


def tar_regular(
    path: bytes,
    payload: bytes = b"",
    *,
    format_name: str = "posix",
    mode: int = 0o644,
    size_field: Optional[bytes] = None,
    checksum_mode: str = "unsigned",
    padding_byte: int = 0,
    prefix: bytes = b"",
    old_prefix_bytes: bytes = b"",
) -> bytes:
    builder = {"posix": posix_header, "legacy": legacy_header, "gnu": gnu_header}[format_name]
    header = builder(
        name=path,
        prefix=prefix,
        mode=mode,
        size=len(payload),
        size_field=size_field,
        typeflag=b"0",
        checksum_mode=checksum_mode,
        old_prefix_bytes=old_prefix_bytes,
    )
    return member(header, payload, padding_byte)


def tar_directory(path: bytes, *, size: int = 0, payload: bytes = b"") -> bytes:
    return member(posix_header(name=path, mode=0o755, size=size, typeflag=b"5"), payload)


def complete_tar(parts: Sequence[bytes], extra_zero_blocks: int = 0) -> bytes:
    return b"".join(parts) + end_marker(extra_zero_blocks)


def _path_4096() -> bytes:
    components = [b"a" * 255 for _ in range(15)] + [b"b" * 254, b"c"]
    value = b"/".join(components)
    if len(value) != 4096:
        raise FixtureError("4096-byte path construction failed")
    return value


def _path_4097() -> bytes:
    components = [b"a" * 255 for _ in range(16)] + [b"z"]
    value = b"/".join(components)
    if len(value) != 4097:
        raise FixtureError("4097-byte path construction failed")
    return value


def _one_mib_pax_payload() -> bytes:
    target = 1 << 20
    prefix = str(target).encode("ascii")
    fixed = len(prefix) + 1 + len(b"x=") + 1
    value = b"a" * (target - fixed)
    record = prefix + b" " + b"x=" + value + b"\n"
    if len(record) != target:
        raise FixtureError("1 MiB PAX record construction failed")
    return record


def accepted_tar(case_id: str) -> Tuple[bytes, int, int]:
    if case_id == "A001":
        payload = b"abc"
        return complete_tar([tar_directory(b"dir/"), tar_regular(b"dir/file", payload)]), 2, 3
    if case_id == "A002":
        return complete_tar([tar_regular(b"legacy", b"L", format_name="legacy")]), 1, 1
    if case_id == "A003":
        return complete_tar([tar_regular(b"gnu-file", b"G", format_name="gnu", old_prefix_bytes=b"ignored-prefix")]), 1, 1
    if case_id == "A004":
        return complete_tar([tar_regular(b"file", b"P", prefix=b"prefix")]), 1, 1
    if case_id == "A005":
        return complete_tar([tar_directory(b"."), tar_regular(b"file", b"R")]), 2, 1
    if case_id == "A006":
        return complete_tar([tar_regular(b"././file", b"N")]), 1, 1
    if case_id == "A007":
        return complete_tar([tar_directory(b"directory/")]), 1, 0
    if case_id == "A008":
        return complete_tar([tar_regular(b"empty")]), 1, 0
    if case_id == "A009":
        return complete_tar([tar_regular(b"padding", b"X", padding_byte=0xA5)]), 1, 1
    if case_id == "A010":
        pax = pax_record(b"path", b"pax/renamed")
        body = pax_then_member(pax, posix_header(name=b"placeholder", size=0, typeflag=b"0"))
        return complete_tar([body]), 1, 0
    if case_id == "A011":
        pax = pax_record(b"size", b"3")
        body = pax_then_member(pax, posix_header(name=b"sized", size=0, typeflag=b"0"), b"XYZ")
        return complete_tar([body]), 1, 3
    if case_id == "A012":
        pax = pax_record(b"vendor.key", b"value")
        body = pax_then_member(pax, posix_header(name=b"unknown-pax", size=1, typeflag=b"0"), b"U")
        return complete_tar([body]), 1, 1
    if case_id == "A013":
        pax = pax_record(b"vendor.binary", b"\xff\xfe")
        body = pax_then_member(pax, posix_header(name=b"binary-pax", size=1, typeflag=b"0"), b"B")
        return complete_tar([body]), 1, 1
    if case_id == "A014":
        global_pax = metadata_member(b"g", pax_record(b"vendor.global", b"metadata"))
        return complete_tar([global_pax, tar_regular(b"global", b"Q")]), 1, 1
    if case_id == "A015":
        long_path = b"long/" + b"n" * 180
        body = gnu_long_then_member(b"L", long_path, posix_header(name=b"placeholder", size=0, typeflag=b"0"))
        return complete_tar([body]), 1, 0
    if case_id == "A016":
        path = b"c" * 255
        body = pax_then_member(pax_record(b"path", path), posix_header(name=b"placeholder", size=0, typeflag=b"0"))
        return complete_tar([body]), 1, 0
    if case_id == "A017":
        body = pax_then_member(pax_record(b"path", _path_4096()), posix_header(name=b"placeholder", size=0, typeflag=b"0"))
        return complete_tar([body]), 1, 0
    if case_id == "A018":
        return complete_tar([tar_regular(b"base256", size_field=base256_field(0, 12))]), 1, 0
    if case_id == "A019":
        return complete_tar([tar_regular(b"extra-zero", b"Z")], extra_zero_blocks=3), 1, 1
    if case_id == "A020":
        return complete_tar([tar_regular(b"parent/child", b"I"), tar_directory(b"parent/")]), 2, 1
    raise FixtureError(f"unknown accepted fixture {case_id}")


def rejected_tar(case_id: str) -> bytes:
    if case_id == "R001":
        return complete_tar([tar_regular(b"/absolute-secret")])
    if case_id == "R002":
        return complete_tar([tar_regular(b"safe/../escape-secret")])
    if case_id == "R003":
        return complete_tar([tar_regular(b"safe/./dot-secret")])
    if case_id == "R004":
        return complete_tar([tar_regular(b"safe\\backslash-secret")])
    if case_id == "R005":
        return complete_tar([tar_regular(b"safe//double-secret")])
    if case_id == "R006":
        return complete_tar([tar_regular(b"control-\x01-secret")])
    if case_id == "R007":
        header = posix_header(name=b"invalid-\xff-secret", size=0, typeflag=b"0")
        return complete_tar([member(header)])
    if case_id == "R008":
        header = posix_header(name=b"signed-\xff-secret", size=0, typeflag=b"0", checksum_mode="signed")
        return complete_tar([member(header)])
    if case_id == "R009":
        return complete_tar([tar_regular(b"regular-slash-secret/")])
    if case_id == "R010":
        return complete_tar([tar_regular(b".")])
    if case_id == "R011":
        pax = pax_record(b"path", b"x" * 256)
        return complete_tar([pax_then_member(pax, posix_header(name=b"placeholder", size=0, typeflag=b"0"))])
    if case_id == "R012":
        pax = pax_record(b"path", _path_4097())
        return complete_tar([pax_then_member(pax, posix_header(name=b"placeholder", size=0, typeflag=b"0"))])
    if case_id == "R013":
        return complete_tar([tar_regular(b"duplicate-secret"), tar_regular(b"duplicate-secret")])
    if case_id == "R014":
        return complete_tar([tar_regular(b"./normalized-secret"), tar_regular(b"normalized-secret")])
    if case_id == "R015":
        return complete_tar([tar_regular(b"file-parent-secret"), tar_regular(b"file-parent-secret/child")])
    if case_id == "R016":
        return complete_tar([tar_regular(b"implicit-parent-secret/child"), tar_regular(b"implicit-parent-secret")])
    if case_id == "R017":
        return complete_tar([tar_regular(b"type-conflict-secret"), tar_directory(b"type-conflict-secret/")])
    if case_id in {"R018", "R019", "R020", "R021", "R022", "R023", "R024", "R025"}:
        type_map = {
            "R018": b"2",
            "R019": b"1",
            "R020": b"3",
            "R021": b"4",
            "R022": b"6",
            "R023": b"7",
            "R024": b"S",
            "R025": b"V",
        }
        link = b"link-target-secret" if case_id in {"R018", "R019"} else b""
        return complete_tar([member(posix_header(name=b"unsupported-type-secret", size=0, typeflag=type_map[case_id], linkname=link))])
    if case_id == "R026":
        return complete_tar([tar_regular(b"setuid-secret", mode=0o4755)])
    if case_id == "R027":
        return complete_tar([tar_regular(b"setgid-secret", mode=0o2755)])
    if case_id == "R028":
        return complete_tar([tar_directory(b"nonempty-dir-secret/", size=1, payload=b"D")])
    if case_id == "R029":
        header = posix_header(name=b"bad-checksum-secret", size=0, typeflag=b"0", checksum_mode="invalid")
        return complete_tar([member(header)])
    if case_id == "R030":
        header = tar_header(name=b"bad-magic-secret", size=0, typeflag=b"0", magic=b"badbad", version=b"00")
        return complete_tar([member(header)])
    if case_id == "R031":
        header = tar_header(name=b"bad-posix-version", size=0, typeflag=b"0", magic=b"ustar\0", version=b"01")
        return complete_tar([member(header)])
    if case_id == "R032":
        header = tar_header(name=b"bad-gnu-version", size=0, typeflag=b"0", magic=b"ustar ", version=b"00")
        return complete_tar([member(header)])
    if case_id == "R033":
        header = posix_header(name=b"bad-octal-secret", size=0, typeflag=b"0", mode_field=b"00000x\0 ")
        return complete_tar([member(header)])
    if case_id == "R034":
        header = posix_header(name=b"negative-base256", size=0, size_field=invalid_negative_base256(12), typeflag=b"0")
        return complete_tar([member(header)])
    if case_id == "R035":
        header = posix_header(name=b"huge-file-secret", size=0, size_field=base256_field((64 << 30) + 1, 12), typeflag=b"0")
        return complete_tar([member(header)])
    if case_id == "R036":
        first = tar_regular(b"first-secret")
        second = tar_regular(b"after-single-zero-secret")
        return first + b"\0" * BLOCK + second + end_marker()
    if case_id == "R037":
        return tar_regular(b"missing-end-secret")
    if case_id == "R038":
        return tar_regular(b"single-end-secret") + b"\0" * BLOCK
    if case_id == "R039":
        partial = posix_header(name=b"partial-header-secret", size=0, typeflag=b"0")[:101]
        return tar_regular(b"complete-first-secret") + partial
    if case_id == "R040":
        header = posix_header(name=b"partial-payload-secret", size=10, typeflag=b"0")
        return header + b"12345"
    if case_id == "R041":
        header = posix_header(name=b"partial-padding-secret", size=1, typeflag=b"0")
        return header + b"X" + b"\0" * 100
    if case_id == "R042":
        return tar_regular(b"after-end-secret") + end_marker() + b"\x01"
    if case_id in {"R043", "R044", "R045", "R046"}:
        return complete_tar([tar_regular(b"compression-policy-secret", b"C")])
    if case_id in {"R047", "R048", "R049", "R050", "R051", "R052", "R053", "R054", "R055", "R056"}:
        if case_id == "R047":
            payload = b"x path=malformed-secret\n"
            typeflag = b"x"
        elif case_id == "R048":
            payload = b"12 path=abcX"
            typeflag = b"x"
        elif case_id == "R049":
            payload = pax_raw_content(b"missingequalssecret\n")
            typeflag = b"x"
        elif case_id == "R050":
            payload = pax_record(b"vendor.nul", b"nul\0secret")
            typeflag = b"x"
        elif case_id == "R051":
            payload = pax_raw_content(b"bad key=value-secret\n")
            typeflag = b"x"
        elif case_id == "R052":
            payload = pax_record(b"path", b"first-secret") + pax_record(b"path", b"second-secret")
            typeflag = b"x"
        elif case_id == "R053":
            payload = pax_record(b"path", b"global-path-secret")
            typeflag = b"g"
        elif case_id == "R054":
            payload = pax_record(b"GNU.sparse.map", b"0,1")
            typeflag = b"x"
        elif case_id == "R055":
            payload = pax_record(b"path", b"invalid-\xff-secret")
            typeflag = b"x"
        else:
            payload = pax_record(b"size", b"12x-secret")
            typeflag = b"x"
        return complete_tar([metadata_member(typeflag, payload)])
    if case_id == "R057":
        first = metadata_member(b"x", pax_record(b"path", b"pax-path-secret"))
        second = metadata_member(b"L", b"gnu-long-secret\0", name=b"././@LongLink")
        return complete_tar([first, second])
    if case_id == "R058":
        return complete_tar([metadata_member(b"L", b"\0", name=b"././@LongLink")])
    if case_id == "R059":
        return complete_tar([metadata_member(b"L", b"interior\0nul-secret\0", name=b"././@LongLink")])
    if case_id == "R060":
        return complete_tar([metadata_member(b"L", b"invalid-\xff-secret\0", name=b"././@LongLink")])
    if case_id == "R061":
        first = metadata_member(b"K", b"link-target-secret\0", name=b"././@LongLink")
        second = tar_regular(b"regular-after-link-secret")
        return complete_tar([first, second])
    if case_id == "R062":
        return metadata_member(b"x", pax_record(b"vendor.pending", b"pending-secret")) + end_marker()
    if case_id == "R063":
        header = posix_header(name=b"oversized-metadata-secret", size=(1 << 20) + 1, typeflag=b"x")
        return complete_tar([member(header)])
    if case_id == "R064":
        payload = _one_mib_pax_payload()
        complete = metadata_member(b"g", payload, name=b"GlobalPax")
        seventeenth = posix_header(name=b"GlobalPax17", size=1 << 20, typeflag=b"g")
        return b"".join([complete] * 16) + seventeenth + end_marker()
    if case_id in {"R065", "R066"}:
        return complete_tar([tar_regular(b"declaration-secret", b"DATA")])
    raise FixtureError(f"unknown rejected fixture {case_id}")


EXPECTED_REJECTIONS: Dict[str, Tuple[int, str]] = {
    "R001": (8, "$.artifacts[0].members[0].path"),
    "R002": (8, "$.artifacts[0].members[0].path"),
    "R003": (8, "$.artifacts[0].members[0].path"),
    "R004": (8, "$.artifacts[0].members[0].path"),
    "R005": (8, "$.artifacts[0].members[0].path"),
    "R006": (8, "$.artifacts[0].members[0].path"),
    "R007": (8, "$.artifacts[0].members[0].path"),
    "R008": (8, "$.artifacts[0].members[0].path"),
    "R009": (8, "$.artifacts[0].members[0].path"),
    "R010": (8, "$.artifacts[0].members[0].path"),
    "R011": (12, "$.artifacts[0].members[1].path"),
    "R012": (12, "$.artifacts[0].members[1].path"),
    "R013": (9, "$.artifacts[0].members[1].path"),
    "R014": (9, "$.artifacts[0].members[1].path"),
    "R015": (9, "$.artifacts[0].members[1].path"),
    "R016": (9, "$.artifacts[0].members[1].path"),
    "R017": (9, "$.artifacts[0].members[1].path"),
    "R018": (10, "$.artifacts[0].members[0].type"),
    "R019": (10, "$.artifacts[0].members[0].type"),
    "R020": (10, "$.artifacts[0].members[0].type"),
    "R021": (10, "$.artifacts[0].members[0].type"),
    "R022": (10, "$.artifacts[0].members[0].type"),
    "R023": (10, "$.artifacts[0].members[0].type"),
    "R024": (10, "$.artifacts[0].members[0].type"),
    "R025": (10, "$.artifacts[0].members[0].type"),
    "R026": (10, "$.artifacts[0].members[0].type"),
    "R027": (10, "$.artifacts[0].members[0].type"),
    "R028": (7, "$.artifacts[0].members[0].type"),
    "R029": (7, "$.artifacts[0].members[0]"),
    "R030": (7, "$.artifacts[0].members[0]"),
    "R031": (7, "$.artifacts[0].members[0]"),
    "R032": (7, "$.artifacts[0].members[0]"),
    "R033": (7, "$.artifacts[0].members[0]"),
    "R034": (7, "$.artifacts[0].members[0]"),
    "R035": (12, "$.artifacts[0].members[0].type"),
    "R036": (7, "$.artifacts[0].members[1]"),
    "R037": (6, "$.artifacts[0].members[1]"),
    "R038": (6, "$.artifacts[0].members[1]"),
    "R039": (6, "$.artifacts[0].members[1]"),
    "R040": (6, "$.artifacts[0].members[1]"),
    "R041": (6, "$.artifacts[0].members[1]"),
    "R042": (7, "$.artifacts[0].members[1]"),
    "R043": (5, "$.data.archive"),
    "R044": (6, "$.data.archive"),
    "R045": (5, "$.data.archive"),
    "R046": (5, "$.data.archive"),
    "R047": (11, "$.artifacts[0].members[0]"),
    "R048": (11, "$.artifacts[0].members[0]"),
    "R049": (11, "$.artifacts[0].members[0]"),
    "R050": (11, "$.artifacts[0].members[0]"),
    "R051": (11, "$.artifacts[0].members[0]"),
    "R052": (11, "$.artifacts[0].members[0]"),
    "R053": (11, "$.artifacts[0].members[0]"),
    "R054": (10, "$.artifacts[0].members[0]"),
    "R055": (11, "$.artifacts[0].members[0]"),
    "R056": (11, "$.artifacts[0].members[0]"),
    "R057": (11, "$.artifacts[0].members[1]"),
    "R058": (11, "$.artifacts[0].members[0]"),
    "R059": (11, "$.artifacts[0].members[0]"),
    "R060": (11, "$.artifacts[0].members[0]"),
    "R061": (11, "$.artifacts[0].members[1].type"),
    "R062": (11, "$.artifacts[0].members[1]"),
    "R063": (12, "$.artifacts[0].members[0]"),
    "R064": (12, "$.artifacts[0].members[16]"),
    "R065": (13, "$.data.archive"),
    "R066": (14, "$.data.archive"),
}


def fixture_ids() -> List[str]:
    return [f"A{index:03d}" for index in range(1, 21)] + [f"R{index:03d}" for index in range(1, 67)]


def _forbidden_fragments(case_id: str) -> List[str]:
    return [f"raw-{case_id}-secret", f"malicious-{case_id}-value"]


def build_archive(case_id: str) -> Tuple[bytes, Optional[int], Optional[int]]:
    if case_id.startswith("A"):
        tar_bytes, members, regular_bytes = accepted_tar(case_id)
        return gzip_stored(tar_bytes), members, regular_bytes
    tar_bytes = rejected_tar(case_id)
    archive = gzip_stored(tar_bytes)
    if case_id == "R043":
        mutated = bytearray(archive)
        mutated[2] = 0
        archive = bytes(mutated)
    elif case_id == "R044":
        archive = archive[:-1]
    elif case_id == "R045":
        archive = archive + gzip_stored(complete_tar([tar_regular(b"second-member-secret")]))
    elif case_id == "R046":
        archive = archive + b"TRAILING-COMPRESSED-SECRET"
    return archive, None, None


def build_case(case_id: str) -> Tuple[Dict[str, object], bytes]:
    archive, expected_members, expected_regular_bytes = build_archive(case_id)
    archive_name = f"{case_id}.tar.gz"
    actual_size = len(archive)
    actual_digest = sha256_bytes(archive)
    declared_size = actual_size
    declared_digest = actual_digest
    if case_id == "R065":
        declared_size = actual_size + 1
    if case_id == "R066":
        replacement = "0" if actual_digest[0] != "0" else "1"
        declared_digest = replacement + actual_digest[1:]
    common: Dict[str, object] = {
        "id": case_id,
        "archiveName": archive_name,
        "expectedDisposition": "accepted" if case_id.startswith("A") else "rejected",
        "declaredSize": declared_size,
        "declaredSHA256": declared_digest,
        "forbiddenErrorFragments": [] if case_id.startswith("A") else _forbidden_fragments(case_id),
    }
    if case_id.startswith("A"):
        common["expectedMemberCount"] = expected_members
        common["expectedRegularFileBytes"] = expected_regular_bytes
    else:
        code, field_path = EXPECTED_REJECTIONS[case_id]
        common["expectedErrorCode"] = code
        common["expectedErrorFieldPath"] = field_path
    return common, archive


def build_corpus() -> Tuple[Dict[str, object], Dict[str, bytes]]:
    cases: List[Dict[str, object]] = []
    files: Dict[str, bytes] = {}
    for case_id in fixture_ids():
        record, archive = build_case(case_id)
        cases.append(record)
        files[str(record["archiveName"])] = archive
    metadata: Dict[str, object] = {
        "schemaVersion": SCHEMA_VERSION,
        "fixtureCount": FIXTURE_COUNT,
        "acceptedCount": ACCEPTED_COUNT,
        "rejectedCount": REJECTED_COUNT,
        "cases": cases,
    }
    metadata_bytes = (json.dumps(metadata, sort_keys=True, separators=(",", ":"), ensure_ascii=True) + "\n").encode("utf-8")
    files["fixtures.json"] = metadata_bytes
    checksum_lines = [
        f"{sha256_bytes(files[name])}  {name}\n".encode("ascii")
        for name in sorted(files, key=lambda item: item.encode("utf-8"))
    ]
    files["corpus.sha256"] = b"".join(checksum_lines)
    return metadata, files


def _all_ancestors_real(path: Path) -> bool:
    current = path
    while True:
        try:
            status = os.lstat(current)
        except OSError:
            return False
        if stat.S_ISLNK(status.st_mode) or not stat.S_ISDIR(status.st_mode):
            return False
        if current.parent == current:
            return True
        current = current.parent


def _atomic_write(path: Path, data: bytes, mode: int) -> None:
    temporary = path.with_name(path.name + ".tmp")
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
    if hasattr(os, "O_NOFOLLOW"):
        flags |= os.O_NOFOLLOW
    descriptor = os.open(temporary, flags, mode)
    try:
        offset = 0
        while offset < len(data):
            written = os.write(descriptor, data[offset:])
            if written <= 0:
                raise FixtureError("fixture write made no progress")
            offset += written
        os.fsync(descriptor)
    finally:
        os.close(descriptor)
    os.chmod(temporary, mode)
    os.replace(temporary, path)


def generate_to_directory(raw_output: str, fail_after: Optional[int] = None) -> Tuple[int, str, int]:
    if not isinstance(raw_output, str) or not raw_output:
        raise FixtureError("output directory is required")
    output = Path(raw_output)
    if os.path.lexists(output):
        raise FixtureError("output directory already exists")
    parent = output.parent if str(output.parent) else Path(".")
    if not _all_ancestors_real(parent.absolute()):
        raise FixtureError("output parent must be a real directory")
    metadata, files = build_corpus()
    created = False
    try:
        os.mkdir(output, 0o700)
        created = True
        os.chmod(output, 0o700)
        fixture_names = [f"A{index:03d}.tar.gz" for index in range(1, 21)] + [f"R{index:03d}.tar.gz" for index in range(1, 67)]
        write_order = fixture_names + ["fixtures.json", "corpus.sha256"]
        for index, name in enumerate(write_order):
            if fail_after is not None and index == fail_after:
                raise FixtureError("injected generation failure")
            _atomic_write(output / name, files[name], 0o600)
        total_fixture_bytes = sum(len(files[name]) for name in fixture_names)
        corpus_hash = sha256_bytes(b"".join(files[name] for name in sorted(fixture_names)))
        return total_fixture_bytes, corpus_hash, len(metadata["cases"])
    except Exception:
        if created:
            shutil.rmtree(output, ignore_errors=True)
        raise


def _directory_bytes(root: Path) -> Dict[str, bytes]:
    result: Dict[str, bytes] = {}
    for path in sorted(root.iterdir(), key=lambda item: item.name.encode("utf-8")):
        if not path.is_file() or path.is_symlink():
            raise FixtureError("generated corpus contains a non-regular file")
        result[path.name] = path.read_bytes()
    return result


def run_self_test() -> Tuple[int, int]:
    tests = TestCounter()
    tests.equal(octal_field(0, 8), b"0000000\0", "octal zero")
    tests.equal(octal_field(0o755, 8), b"0000755\0", "octal mode")
    tests.equal(int(octal_field(12345, 12).rstrip(b"\0"), 8), 12345, "octal round trip")
    tests.equal(base256_field(0, 12), b"\x80" + b"\0" * 11, "base-256 zero")
    tests.check(base256_field(64 << 30, 12)[0] & 0x80 != 0, "base-256 marker")
    tests.check(invalid_negative_base256(12)[0] & 0x40 != 0, "negative base-256 marker")

    posix = posix_header(name=b"file", size=0, typeflag=b"0")
    legacy = legacy_header(name=b"file", size=0, typeflag=b"0")
    gnu = gnu_header(name=b"file", size=0, typeflag=b"0")
    tests.equal(len(posix), BLOCK, "header width")
    tests.equal(posix[257:265], b"ustar\x0000", "POSIX magic/version")
    tests.equal(legacy[257:265], b"\0" * 8, "legacy magic/version")
    tests.equal(gnu[257:265], b"ustar  \0", "GNU magic/version")
    tests.equal(posix[156:157], b"0", "regular header type")
    tests.equal(posix_header(name=b"dir/", size=0, typeflag=b"5")[156:157], b"5", "directory header type")
    tests.check(posix[148:156].endswith(b"\0 "), "unsigned checksum construction")
    signed = posix_header(name=b"signed-\xff", size=0, typeflag=b"0", checksum_mode="signed")
    tests.check(signed[148:156].endswith(b"\0 "), "signed checksum construction")

    record = pax_record(b"path", b"abc")
    tests.equal(int(record.split(b" ", 1)[0]), len(record), "PAX length stabilization")
    tests.check(record.endswith(b"path=abc\n"), "PAX payload")
    tests.check(metadata_member(b"L", b"long\0")[156:157] == b"L", "GNU L payload")
    tests.check(metadata_member(b"K", b"link\0")[156:157] == b"K", "GNU K payload")
    tests.equal(len(payload_padding(0)), 0, "zero padding")
    tests.equal(len(payload_padding(1)), 511, "payload padding")
    tests.equal(len(end_marker()), 1024, "two-zero-block marker")

    one_block = gzip_stored(b"abc")
    many_block_payload = b"m" * 70000
    many_block = gzip_stored(many_block_payload)
    tests.equal(parse_stored_gzip(one_block), b"abc", "stored DEFLATE one block")
    tests.equal(parse_stored_gzip(many_block), many_block_payload, "stored DEFLATE multiple blocks")
    tests.equal(one_block[:10], b"\x1f\x8b\x08\x00\x00\x00\x00\x00\x00\xff", "deterministic gzip header")
    tests.equal(struct.unpack("<I", one_block[-8:-4])[0], binascii.crc32(b"abc") & 0xFFFFFFFF, "gzip CRC")
    tests.equal(struct.unpack("<I", one_block[-4:])[0], 3, "gzip ISIZE")
    tests.check(len(one_block + one_block) == len(one_block) * 2, "concatenated gzip construction")
    tests.check((one_block + b"garbage").endswith(b"garbage"), "trailing garbage construction")
    tests.equal(one_block[:-1], gzip_stored(b"abc")[:-1], "gzip truncation construction")

    ids = fixture_ids()
    tests.equal(len(ids), FIXTURE_COUNT, "exact fixture count")
    tests.equal(ids[:2], ["A001", "A002"], "accepted ID prefix")
    tests.equal(ids[19], "A020", "accepted ID suffix")
    tests.equal(ids[20], "R001", "rejected ID prefix")
    tests.equal(ids[-1], "R066", "rejected ID suffix")
    tests.equal(len(set(ids)), FIXTURE_COUNT, "unique fixture IDs")
    tests.equal(len(EXPECTED_REJECTIONS), REJECTED_COUNT, "exact rejected expectation count")
    tests.equal(EXPECTED_REJECTIONS["R011"], (12, "$.artifacts[0].members[1].path"), "corrected R011 field")
    tests.equal(EXPECTED_REJECTIONS["R012"], (12, "$.artifacts[0].members[1].path"), "corrected R012 field")
    tests.equal(EXPECTED_REJECTIONS["R054"][0], 10, "R054 unsupported sparse type")

    metadata, files = build_corpus()
    tests.equal(set(metadata), {"schemaVersion", "fixtureCount", "acceptedCount", "rejectedCount", "cases"}, "exact top-level JSON schema")
    tests.equal(metadata["schemaVersion"], 1, "schema version")
    tests.equal(metadata["fixtureCount"], 86, "metadata fixture count")
    tests.equal(metadata["acceptedCount"], 20, "metadata accepted count")
    tests.equal(metadata["rejectedCount"], 66, "metadata rejected count")
    cases = metadata["cases"]
    assert isinstance(cases, list)
    tests.equal([case["id"] for case in cases], ids, "case ordering")
    tests.equal(len({case["archiveName"] for case in cases}), 86, "no duplicate archive names")
    tests.equal(len(files), 88, "corpus file count including metadata")
    tests.check(files["fixtures.json"].endswith(b"\n") and b"\r" not in files["fixtures.json"], "deterministic JSON LF")
    tests.check(files["fixtures.json"] == (json.dumps(metadata, sort_keys=True, separators=(",", ":"), ensure_ascii=True) + "\n").encode("utf-8"), "exact JSON serialization")
    checksum_lines = files["corpus.sha256"].decode("ascii").splitlines()
    tests.equal(len(checksum_lines), 87, "checksum coverage")
    tests.check(all(len(line.split("  ")[0]) == 64 for line in checksum_lines), "checksum digest width")
    tests.check(all(line.split("  ")[0] == line.split("  ")[0].lower() for line in checksum_lines), "checksum lowercase")
    checksum_names = [line.split("  ", 1)[1] for line in checksum_lines]
    tests.equal(checksum_names, sorted(checksum_names, key=lambda item: item.encode("utf-8")), "checksum byte sorting")
    tests.check("corpus.sha256" not in checksum_names, "checksum self exclusion")

    distribution: Dict[int, int] = {}
    for case in cases:
        if case["expectedDisposition"] == "rejected":
            code = int(case["expectedErrorCode"])
            distribution[code] = distribution.get(code, 0) + 1
    tests.equal(distribution, ERROR_DISTRIBUTION, "corrected error distribution")
    tests.equal(distribution[11], 15, "InvalidExtendedHeader corrected count")
    tests.equal(distribution[12], 5, "LimitExceeded corrected count")
    tests.equal(sum(distribution.values()), 66, "rejected distribution total")

    accepted_cases = [case for case in cases if case["expectedDisposition"] == "accepted"]
    rejected_cases = [case for case in cases if case["expectedDisposition"] == "rejected"]
    tests.equal(len(accepted_cases), 20, "accepted split")
    tests.equal(len(rejected_cases), 66, "rejected split")
    accepted_keys = {"id", "archiveName", "expectedDisposition", "declaredSize", "declaredSHA256", "forbiddenErrorFragments", "expectedMemberCount", "expectedRegularFileBytes"}
    rejected_keys = {"id", "archiveName", "expectedDisposition", "declaredSize", "declaredSHA256", "forbiddenErrorFragments", "expectedErrorCode", "expectedErrorFieldPath"}
    tests.check(all(set(case) == accepted_keys for case in accepted_cases), "accepted exact keys")
    tests.check(all(set(case) == rejected_keys for case in rejected_cases), "rejected exact keys")
    tests.check(all(case["forbiddenErrorFragments"] for case in rejected_cases), "rejected privacy fragments")
    tests.check(all(len(fragment) >= 2 for case in rejected_cases for fragment in case["forbiddenErrorFragments"]), "privacy fragment minimum length")

    tests.equal(len(_path_4096()), 4096, "4096 path boundary")
    tests.equal(max(map(len, _path_4096().split(b"/"))), 255, "4096 path component boundary")
    tests.equal(len(_path_4097()), 4097, "4097 path construction")
    tests.equal(max(map(len, _path_4097().split(b"/"))), 255, "4097 path avoids component overflow")
    tests.equal(len(_one_mib_pax_payload()), 1 << 20, "1 MiB metadata payload")
    tests.equal(len(rejected_tar("R064")), 16 * ((1 << 20) + BLOCK) + BLOCK + 1024, "metadata aggregate construction")

    r011_tar = rejected_tar("R011")
    r012_tar = rejected_tar("R012")
    tests.equal(r011_tar[156:157], b"x", "R011 metadata header at physical zero")
    r011_real_offset = BLOCK + len(pax_record(b"path", b"x" * 256)) + len(payload_padding(len(pax_record(b"path", b"x" * 256))))
    tests.equal(r011_tar[r011_real_offset + 156 : r011_real_offset + 157], b"0", "R011 real header at physical one")
    tests.equal(r012_tar[156:157], b"x", "R012 metadata header at physical zero")

    temporary_parent = Path(tempfile.gettempdir()).resolve(strict=True)
    if not _all_ancestors_real(temporary_parent):
        raise FixtureError("self-test temporary parent must resolve to a real directory")
    with tempfile.TemporaryDirectory(prefix="px-fixture-selftest-", dir=str(temporary_parent)) as temporary:
        root = Path(temporary)
        first = root / "corpus-a"
        second = root / "corpus-b"
        total_a, hash_a, count_a = generate_to_directory(str(first))
        total_b, hash_b, count_b = generate_to_directory(str(second))
        bytes_a = _directory_bytes(first)
        bytes_b = _directory_bytes(second)
        tests.equal(count_a, 86, "generation A fixture count")
        tests.equal(count_b, 86, "generation B fixture count")
        tests.equal(total_a, total_b, "corpus total bytes deterministic")
        tests.equal(hash_a, hash_b, "corpus aggregate hash deterministic")
        tests.equal(set(bytes_a), set(bytes_b), "corpus relative files deterministic")
        tests.equal(bytes_a, bytes_b, "corpus bytes deterministic")
        tests.equal(bytes_a["fixtures.json"], bytes_b["fixtures.json"], "JSON byte identity")
        tests.equal(bytes_a["corpus.sha256"], bytes_b["corpus.sha256"], "checksum byte identity")
        tests.equal(len([name for name in bytes_a if name.endswith(".tar.gz")]), 86, "generated archive count")
        tests.check(all((first / name).parent == first for name in bytes_a), "output root containment")
        if os.name != "nt":
            tests.equal(stat.S_IMODE(os.stat(first).st_mode), 0o700, "output root mode")
            tests.check(all(stat.S_IMODE(os.stat(first / name).st_mode) == 0o600 for name in bytes_a), "generated file modes")
        failure = root / "failed-corpus"
        try:
            generate_to_directory(str(failure), fail_after=3)
        except FixtureError:
            pass
        else:
            raise FixtureError("injected output failure did not fail")
        tests.check(not failure.exists(), "output cleanup on failure")
        try:
            generate_to_directory(str(first))
        except FixtureError:
            pass
        else:
            raise FixtureError("existing output directory was overwritten")
        tests.check(first.exists(), "existing corpus preserved")

    tests.check(tests.total >= 64, "minimum self-test count")
    return tests.passed, tests.total


def usage_error() -> int:
    print(
        "archive fixture generator: usage: generate_archive_fixtures.py --self-test | --output <directory>",
        file=sys.stderr,
    )
    return 2


def main(argv: Sequence[str]) -> int:
    if list(argv) == ["--self-test"]:
        try:
            passed, total = run_self_test()
        except Exception as exc:
            print(f"archive fixture generator self-test: FAIL ({exc})", file=sys.stderr)
            return 1
        print(f"archive fixture generator self-test: PASS ({passed}/{total})")
        return 0
    if len(argv) == 2 and argv[0] == "--output" and argv[1]:
        try:
            generate_to_directory(argv[1])
        except Exception as exc:
            print(f"archive fixture generator: {exc}", file=sys.stderr)
            return 2
        print("archive fixture generation: PASS (86 fixtures; accepted=20 rejected=66)")
        return 0
    return usage_error()


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv[1:]))
    except KeyboardInterrupt:
        print("archive fixture generator: interrupted", file=sys.stderr)
        raise SystemExit(2)
