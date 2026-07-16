# TASK-3.10A Report — Fix Top-Level Name Classification and Rollback Errors
## Baseline and exact two-file scope
- Required baseline: `5e70a8ff5572dd343c8a16eb566277ab662e307f`.
- Authorized production modification: `PXBackupStaleWorkspaceCleanup.m`.
- Required new report: `docs/backup-restore-hardening/reports/TASK-3.10A-REPORT.md`.
- Implementation commit scope is exactly those two files. Coordinator-owned modified/untracked files were not staged, reverted, deleted, formatted, or rewritten.
- Baseline host: `DESKTOP-JATSMMU`. Baseline evidence recorded `git status --short --untracked-files=all`, `git rev-parse HEAD`, `git log -8 --oneline`, and clean `git diff --check`.
## Review blocker reproduction
TASK-3.10 used one strict reader for recursive stale-tree names and direct children of the bundle directory. The baseline reader called `PXBackupStaleWorkspaceCleanupValidateEntryName` before reserved-prefix classification; that helper created `NSData`, decoded `NSString`, required a lossless UTF-8 round trip, and rejected control bytes. Consequently a nonreserved direct child such as raw `66 6f 6f ff` or `nonreserved 01` aborted Backup as `UnsafeReservedEntry` instead of being ignored. The same strict path was used by initial preflight, final scan, and successful post-cleanup identity validation.
The baseline capture helper had three post-capture rollback decision sites. Failed first rollback selected `EntryChanged` for identity mismatch and `LimitExceeded` for quarantine-name retention failure; `PXBackupStaleWorkspaceCleanupErrorRollbackFailed` had no active production reference.
## Common reader architecture
The implementation retains exactly one `F_DUPFD_CLOEXEC`, one `fdopendir`, and one `readdir` implementation. The reader now accepts one of two name modes while empty-directory checks reuse the same syscall path without collecting names.
- `StrictRecursiveNames`: used once by bounded recursive deletion inside an exact proven stale workspace. It preserves 1..255-byte bounds, dot/dot-dot rejection, slash/backslash/control rejection, immutable raw `NSData`, lossless UTF-8 `NSString` round trip, visited-entry limits, accumulated-name limits, and fail-closed evidence preservation.
- `RawTopLevelReservedClassification`: used exactly three times: initial preflight, final post-cleanup scan, and successful post-cleanup `validateIdentityWithError:` scan. It counts every non-dot direct child and every raw name byte before classification.
## Raw prefix classification and exact grammar
Raw mode obtains a bounded length without NSString conversion. It compares `d_name` bytes with `.weaponx-backup-partial-` and `.weaponx-cleanup-quarantine-` through the raw `memcmp` prefix helper. A nonmatching name returns `Nonreserved` immediately: it is not converted to NSString, not materialized as candidate NSData, and is not passed to openat/fstatat/rename/unlink/rmdir.
A matching partial prefix is exact only with six ASCII alphanumeric bytes. A matching quarantine prefix is exact only with 32 lowercase ASCII hexadecimal bytes. All short, long, punctuation, uppercase quarantine, non-hex, control, invalid UTF-8, and extra-byte variants return `ReservedNameInvalid` during the complete top-level scan before any recursive cleanup or atomic capture. Only exact reserved names are copied into bounded raw NSData and sorted.
## Opaque nonreserved proof
Source-path audit of the raw classifier reports `NSString=0` and `NSData=0`; the nonreserved branch reports `NSString=0`, `NSData=0`, and child filesystem operation count `0`. The common reader contains no openat, fstatat, renameatx_np, or unlinkat call. Native and Python models accepted `foo ff`, leading `80 81 82`, nonreserved control byte `01`, dot-hidden names, published names, and a 255-byte opaque name without mutation. Limits still count all opaque direct children.
## Malformed reserved fail-closed and final scans
Because prefix detection and exact grammar use raw bytes, malformed reserved invalid UTF-8/control suffixes cannot be misclassified as unrelated opaque names. The initial raw scan returns `ReservedNameInvalid` before candidate allocation/preflight mutation even when a valid exact candidate appears earlier in enumeration. Final raw scans ignore unrelated opaque entries, return `ReservedNameInvalid` for malformed reserved prefixes, and return `CleanupIncomplete` when exact reserved evidence remains. Lock ownership and canonical bundle-directory identity validation remain unchanged.
## Rollback precedence
| Rollback proved | Prior destructive mutation | Operation-specific code | Result |
|---|---|---|---|
| yes | no | EntryChanged | `EntryChanged` |
| yes | yes | EntryChanged | `EntryChanged` |
| no | no | EntryChanged | `RollbackFailed` |
| no | yes | EntryChanged | `CleanupIncomplete` |
| yes | no | LimitExceeded | `LimitExceeded` |
| yes | yes | LimitExceeded | `LimitExceeded` |
| no | no | LimitExceeded | `RollbackFailed` |
| no | yes | LimitExceeded | `CleanupIncomplete` |
A file-local selector implements exactly this precedence. It is called at the identity-mismatch site and both post-capture retention/representation sites. `PXBackupStaleWorkspaceCleanupErrorRollbackFailed` has one active production reference inside the selector; the selector has three production call sites. No unrelated error mapping was changed.
## Evidence preservation and atomic cleanup non-regression
Brace-aware comparison proves `MoveNoReplace`, random quarantine generation, captured-binding validation, rollback execution, regular-file removal, and subdirectory removal are byte-identical to TASK-3.10. The capture function diff consists only of replacing three legacy ternary mappings with the selector. The same no-replace helper, original-name absence requirement, strict parent fsync, quarantine absence proof, original presence proof, and no-overwrite behavior remain. The capture helper contains no unlink/rmdir, so failed rollback returns before destructive callers receive a quarantine name.
The source still has exactly three destructive `unlinkat` sites, each targeting a generated private quarantine name. Original-name destructive sites remain zero. Regular-file, directory, and root capture-before-delete ordering remains; `removedEntryCount` increment sites remain two and `cleanedWorkspaceCount` increment sites remain one, all after durability proofs. Nested prior-quarantine recovery remains enabled inside strict proven stale trees.
## Static gates
| Gate | Result |
|---|---:|
| PXBackupStaleWorkspaceCleanup.h diff | 0 |
| Public error codes / readonly properties | 18 / 4 |
| Factory / cleanup / identity methods | 1 / 1 / 1 |
| F_DUPFD_CLOEXEC / fdopendir / readdir sites | 1 / 1 / 1 |
| Strict recursive scan call paths | 1 |
| Raw top-level scan call paths | 3 |
| renameatx_np / RENAME_EXCL sites | 1 / 1 |
| Plain renameat / dlsym / private syscall sites | 0 / 0 / 0 |
| arc4random_buf sites | 1 |
| Original-name destructive sites | 0 |
| Rollback selector calls / RollbackFailed references | 3 / 1 |
| NSFileManager / shell / process / dispatch additions | 0 / 0 / 0 / 0 |
| Protected production files changed | 0 |
## Function identity proof
| Function | Byte-identical to TASK-3.10 | Current SHA-256 |
|---|---:|---|
| `MoveNoReplace` | TRUE | `320e27ee302ab4a42705bf207a4f43055c1a41d422de3d079e11e84108fe5b1c` |
| `GenerateQuarantineName` | TRUE | `7727c3ee8bddb62c28a94268e11c9af916cc6ce379942af14bc6768621550fa7` |
| `CapturedBindingValid` | TRUE | `801bfa0d3357225d83be286d41435721ddc29fe5bd6e6143222f41601bfb1f6d` |
| `RollbackCapturedMismatch` | TRUE | `7a2e0c649790797b5a9e334649cb5bba5c1083639ade896e6a2a1850887e633d` |
| `RemoveRegularFile` | TRUE | `206a9041e2b576d6b80d78ddc565e377ac2cd961d11ae403ff3decf8f0bd24bd` |
| `RemoveSubdirectory` | TRUE | `dfb0f71d36b5f7dc3e30d2a82886fdc043898ff19816c819ae30086c0e79bb78` |
## Build and test status
- Strict Objective-C frontend/analyzer with portable stat branch: PASS.
- Strict Objective-C frontend/analyzer with `__APPLE__` stat branch: PASS.
- Native C raw-classification/rollback model compiled with MSVC `cl /W4 /WX /O2`: PASS, 49,276 assertions.
- Python raw-byte/fuzz/UTF-8/limit/rollback model: PASS, 69,306 assertions, including 20,000 deterministic random raw names.
- Source-path proof: raw prefix helper uses raw `memcmp`; raw classifier has no NSString/NSData conversion; nonreserved branch has no Foundation child representation or filesystem child operations; strict recursive validator retains lossless UTF-8/control checks.
- Full Theos/Apple SDK arm64/arm64e link and target APFS fault injection are unavailable in this Windows workspace. GitHub Actions and target-device tests remain authoritative for Darwin runtime behavior. This limitation does not affect the reviewed source contradictions, which are directly covered by static compilation and raw-byte models.
## Authorized source before/after
| File | Before SHA-256 | Before bytes | After SHA-256 | After bytes | Lines |
|---|---|---:|---|---:|---:|
| `PXBackupStaleWorkspaceCleanup.m` | `14c50d4f6b85125e07bdb96a9bcad13a8fdaccd4857f9d3c76a0291a38865f74` | 77336 | `f96ed6b3be43b32ef4b31687fd10e797957d93f831fda58bfd39c3b3c26d4584` | 81407 | 1929 |
## Explicit numbered scenario matrix
Explicit scenarios: 262.

| # | Category | Input/state | Expected result |
|---:|---|---|---|
| 1 | raw nonreserved top-level | empty bundle directory | ignore without NSString/NSData child representation or child filesystem operation; preserve byte-for-byte |
| 2 | raw nonreserved top-level | ordinary ASCII filename | ignore without NSString/NSData child representation or child filesystem operation; preserve byte-for-byte |
| 3 | raw nonreserved top-level | dot-hidden nonreserved name .cache | ignore without NSString/NSData child representation or child filesystem operation; preserve byte-for-byte |
| 4 | raw nonreserved top-level | published v2 timestamp directory | ignore without NSString/NSData child representation or child filesystem operation; preserve byte-for-byte |
| 5 | raw nonreserved top-level | published v3 legacy directory | ignore without NSString/NSData child representation or child filesystem operation; preserve byte-for-byte |
| 6 | raw nonreserved top-level | published v4 timestamp/UUID directory | ignore without NSString/NSData child representation or child filesystem operation; preserve byte-for-byte |
| 7 | raw nonreserved top-level | raw bytes 66 6f 6f ff | ignore without NSString/NSData child representation or child filesystem operation; preserve byte-for-byte |
| 8 | raw nonreserved top-level | leading raw bytes 80 81 82 | ignore without NSString/NSData child representation or child filesystem operation; preserve byte-for-byte |
| 9 | raw nonreserved top-level | nonreserved suffix byte 01 | ignore without NSString/NSData child representation or child filesystem operation; preserve byte-for-byte |
| 10 | raw nonreserved top-level | nonreserved suffix byte 7f | ignore without NSString/NSData child representation or child filesystem operation; preserve byte-for-byte |
| 11 | raw nonreserved top-level | nonreserved invalid UTF-8 sequence c0 af | ignore without NSString/NSData child representation or child filesystem operation; preserve byte-for-byte |
| 12 | raw nonreserved top-level | nonreserved invalid UTF-8 sequence ed a0 80 | ignore without NSString/NSData child representation or child filesystem operation; preserve byte-for-byte |
| 13 | raw nonreserved top-level | 255-byte opaque nonreserved name | ignore without NSString/NSData child representation or child filesystem operation; preserve byte-for-byte |
| 14 | raw nonreserved top-level | one opaque regular file | ignore without NSString/NSData child representation or child filesystem operation; preserve byte-for-byte |
| 15 | raw nonreserved top-level | one opaque directory | ignore without NSString/NSData child representation or child filesystem operation; preserve byte-for-byte |
| 16 | raw nonreserved top-level | one opaque symbolic link | ignore without NSString/NSData child representation or child filesystem operation; preserve byte-for-byte |
| 17 | raw nonreserved top-level | one opaque FIFO | ignore without NSString/NSData child representation or child filesystem operation; preserve byte-for-byte |
| 18 | raw nonreserved top-level | one opaque socket | ignore without NSString/NSData child representation or child filesystem operation; preserve byte-for-byte |
| 19 | raw nonreserved top-level | one opaque device entry | ignore without NSString/NSData child representation or child filesystem operation; preserve byte-for-byte |
| 20 | raw nonreserved top-level | physical published directory | ignore without NSString/NSData child representation or child filesystem operation; preserve byte-for-byte |
| 21 | raw nonreserved top-level | 100 opaque entries | ignore without NSString/NSData child representation or child filesystem operation; preserve byte-for-byte |
| 22 | raw nonreserved top-level | 1,000 opaque entries | ignore without NSString/NSData child representation or child filesystem operation; preserve byte-for-byte |
| 23 | raw nonreserved top-level | 16,383 opaque entries | ignore without NSString/NSData child representation or child filesystem operation; preserve byte-for-byte |
| 24 | raw nonreserved top-level | 16,384 opaque entries | ignore without NSString/NSData child representation or child filesystem operation; preserve byte-for-byte |
| 25 | raw nonreserved top-level | 16,385th opaque entry | fail LimitExceeded before mutation while preserving every entry |
| 26 | raw nonreserved top-level | opaque names exactly below 8 MiB aggregate | ignore without NSString/NSData child representation or child filesystem operation; preserve byte-for-byte |
| 27 | raw nonreserved top-level | opaque name causing aggregate-byte overflow | fail LimitExceeded before mutation while preserving every entry |
| 28 | raw nonreserved top-level | opaque names mixed with one exact partial | ignore without NSString/NSData child representation or child filesystem operation; preserve byte-for-byte |
| 29 | raw nonreserved top-level | opaque names mixed with one exact quarantine | ignore without NSString/NSData child representation or child filesystem operation; preserve byte-for-byte |
| 30 | raw nonreserved top-level | opaque names after successful cleanup final scan | ignore without NSString/NSData child representation or child filesystem operation; preserve byte-for-byte |
| 31 | raw nonreserved top-level | opaque names during post-cleanup validateIdentity | ignore without NSString/NSData child representation or child filesystem operation; preserve byte-for-byte |
| 32 | malformed partial | partial suffix length 0 | ReservedNameInvalid before mutation |
| 33 | malformed partial | partial suffix length 1 | ReservedNameInvalid before mutation |
| 34 | malformed partial | partial suffix length 2 | ReservedNameInvalid before mutation |
| 35 | malformed partial | partial suffix length 3 | ReservedNameInvalid before mutation |
| 36 | malformed partial | partial suffix length 4 | ReservedNameInvalid before mutation |
| 37 | malformed partial | partial suffix length 5 | ReservedNameInvalid before mutation |
| 38 | exact partial | partial suffix length 6 ASCII alphanumeric | exact reserved candidate proceeds to no-follow preflight |
| 39 | malformed partial | partial suffix length 7 | ReservedNameInvalid before mutation |
| 40 | malformed partial | - | ReservedNameInvalid before mutation |
| 41 | malformed partial | _ | ReservedNameInvalid before mutation |
| 42 | malformed partial | . | ReservedNameInvalid before mutation |
| 43 | malformed partial | ! | ReservedNameInvalid before mutation |
| 44 | malformed partial | / | ReservedNameInvalid before mutation |
| 45 | malformed partial | \ | ReservedNameInvalid before mutation |
| 46 | malformed partial | space | ReservedNameInvalid before mutation |
| 47 | malformed partial | control 01 | ReservedNameInvalid before mutation |
| 48 | malformed partial | control 1f | ReservedNameInvalid before mutation |
| 49 | malformed partial | DEL 7f | ReservedNameInvalid before mutation |
| 50 | malformed partial | invalid UTF-8 ff | ReservedNameInvalid before mutation |
| 51 | malformed partial | invalid UTF-8 80 | ReservedNameInvalid before mutation |
| 52 | malformed partial | extra trailing byte after ABC123 | ReservedNameInvalid before mutation |
| 53 | exact partial | ABC123 | exact reserved candidate retained as raw NSData and sorted |
| 54 | exact partial | abcdef | exact reserved candidate retained as raw NSData and sorted |
| 55 | exact partial | 000000 | exact reserved candidate retained as raw NSData and sorted |
| 56 | exact partial | Z9z9Z9 | exact reserved candidate retained as raw NSData and sorted |
| 57 | exact partial | Aa0Bb1 | exact reserved candidate retained as raw NSData and sorted |
| 58 | malformed quarantine | quarantine suffix length 0 | ReservedNameInvalid before mutation |
| 59 | malformed quarantine | quarantine suffix length 1 | ReservedNameInvalid before mutation |
| 60 | malformed quarantine | quarantine suffix length 2 | ReservedNameInvalid before mutation |
| 61 | malformed quarantine | quarantine suffix length 3 | ReservedNameInvalid before mutation |
| 62 | malformed quarantine | quarantine suffix length 4 | ReservedNameInvalid before mutation |
| 63 | malformed quarantine | quarantine suffix length 5 | ReservedNameInvalid before mutation |
| 64 | malformed quarantine | quarantine suffix length 6 | ReservedNameInvalid before mutation |
| 65 | malformed quarantine | quarantine suffix length 7 | ReservedNameInvalid before mutation |
| 66 | malformed quarantine | quarantine suffix length 8 | ReservedNameInvalid before mutation |
| 67 | malformed quarantine | quarantine suffix length 9 | ReservedNameInvalid before mutation |
| 68 | malformed quarantine | quarantine suffix length 10 | ReservedNameInvalid before mutation |
| 69 | malformed quarantine | quarantine suffix length 11 | ReservedNameInvalid before mutation |
| 70 | malformed quarantine | quarantine suffix length 12 | ReservedNameInvalid before mutation |
| 71 | malformed quarantine | quarantine suffix length 13 | ReservedNameInvalid before mutation |
| 72 | malformed quarantine | quarantine suffix length 14 | ReservedNameInvalid before mutation |
| 73 | malformed quarantine | quarantine suffix length 15 | ReservedNameInvalid before mutation |
| 74 | malformed quarantine | quarantine suffix length 16 | ReservedNameInvalid before mutation |
| 75 | malformed quarantine | quarantine suffix length 17 | ReservedNameInvalid before mutation |
| 76 | malformed quarantine | quarantine suffix length 18 | ReservedNameInvalid before mutation |
| 77 | malformed quarantine | quarantine suffix length 19 | ReservedNameInvalid before mutation |
| 78 | malformed quarantine | quarantine suffix length 20 | ReservedNameInvalid before mutation |
| 79 | malformed quarantine | quarantine suffix length 21 | ReservedNameInvalid before mutation |
| 80 | malformed quarantine | quarantine suffix length 22 | ReservedNameInvalid before mutation |
| 81 | malformed quarantine | quarantine suffix length 23 | ReservedNameInvalid before mutation |
| 82 | malformed quarantine | quarantine suffix length 24 | ReservedNameInvalid before mutation |
| 83 | malformed quarantine | quarantine suffix length 25 | ReservedNameInvalid before mutation |
| 84 | malformed quarantine | quarantine suffix length 26 | ReservedNameInvalid before mutation |
| 85 | malformed quarantine | quarantine suffix length 27 | ReservedNameInvalid before mutation |
| 86 | malformed quarantine | quarantine suffix length 28 | ReservedNameInvalid before mutation |
| 87 | malformed quarantine | quarantine suffix length 29 | ReservedNameInvalid before mutation |
| 88 | malformed quarantine | quarantine suffix length 30 | ReservedNameInvalid before mutation |
| 89 | malformed quarantine | quarantine suffix length 31 | ReservedNameInvalid before mutation |
| 90 | exact quarantine | quarantine suffix length 32 lowercase hex | exact reserved candidate proceeds to no-follow preflight |
| 91 | malformed quarantine | quarantine suffix length 33 | ReservedNameInvalid before mutation |
| 92 | malformed quarantine | uppercase hex/ASCII byte A | ReservedNameInvalid before mutation |
| 93 | malformed quarantine | uppercase hex/ASCII byte B | ReservedNameInvalid before mutation |
| 94 | malformed quarantine | uppercase hex/ASCII byte C | ReservedNameInvalid before mutation |
| 95 | malformed quarantine | uppercase hex/ASCII byte D | ReservedNameInvalid before mutation |
| 96 | malformed quarantine | uppercase hex/ASCII byte E | ReservedNameInvalid before mutation |
| 97 | malformed quarantine | uppercase hex/ASCII byte F | ReservedNameInvalid before mutation |
| 98 | malformed quarantine | uppercase hex/ASCII byte G | ReservedNameInvalid before mutation |
| 99 | malformed quarantine | uppercase hex/ASCII byte H | ReservedNameInvalid before mutation |
| 100 | malformed quarantine | uppercase hex/ASCII byte I | ReservedNameInvalid before mutation |
| 101 | malformed quarantine | uppercase hex/ASCII byte J | ReservedNameInvalid before mutation |
| 102 | malformed quarantine | uppercase hex/ASCII byte K | ReservedNameInvalid before mutation |
| 103 | malformed quarantine | uppercase hex/ASCII byte L | ReservedNameInvalid before mutation |
| 104 | malformed quarantine | uppercase hex/ASCII byte M | ReservedNameInvalid before mutation |
| 105 | malformed quarantine | uppercase hex/ASCII byte N | ReservedNameInvalid before mutation |
| 106 | malformed quarantine | uppercase hex/ASCII byte O | ReservedNameInvalid before mutation |
| 107 | malformed quarantine | uppercase hex/ASCII byte P | ReservedNameInvalid before mutation |
| 108 | malformed quarantine | uppercase hex/ASCII byte Q | ReservedNameInvalid before mutation |
| 109 | malformed quarantine | uppercase hex/ASCII byte R | ReservedNameInvalid before mutation |
| 110 | malformed quarantine | uppercase hex/ASCII byte S | ReservedNameInvalid before mutation |
| 111 | malformed quarantine | uppercase hex/ASCII byte T | ReservedNameInvalid before mutation |
| 112 | malformed quarantine | uppercase hex/ASCII byte U | ReservedNameInvalid before mutation |
| 113 | malformed quarantine | uppercase hex/ASCII byte V | ReservedNameInvalid before mutation |
| 114 | malformed quarantine | uppercase hex/ASCII byte W | ReservedNameInvalid before mutation |
| 115 | malformed quarantine | uppercase hex/ASCII byte X | ReservedNameInvalid before mutation |
| 116 | malformed quarantine | uppercase hex/ASCII byte Y | ReservedNameInvalid before mutation |
| 117 | malformed quarantine | uppercase hex/ASCII byte Z | ReservedNameInvalid before mutation |
| 118 | malformed quarantine | non-hex lowercase byte g | ReservedNameInvalid before mutation |
| 119 | malformed quarantine | non-hex lowercase byte h | ReservedNameInvalid before mutation |
| 120 | malformed quarantine | non-hex lowercase byte i | ReservedNameInvalid before mutation |
| 121 | malformed quarantine | non-hex lowercase byte j | ReservedNameInvalid before mutation |
| 122 | malformed quarantine | non-hex lowercase byte k | ReservedNameInvalid before mutation |
| 123 | malformed quarantine | non-hex lowercase byte l | ReservedNameInvalid before mutation |
| 124 | malformed quarantine | non-hex lowercase byte m | ReservedNameInvalid before mutation |
| 125 | malformed quarantine | non-hex lowercase byte n | ReservedNameInvalid before mutation |
| 126 | malformed quarantine | non-hex lowercase byte o | ReservedNameInvalid before mutation |
| 127 | malformed quarantine | non-hex lowercase byte p | ReservedNameInvalid before mutation |
| 128 | malformed quarantine | non-hex lowercase byte q | ReservedNameInvalid before mutation |
| 129 | malformed quarantine | non-hex lowercase byte r | ReservedNameInvalid before mutation |
| 130 | malformed quarantine | non-hex lowercase byte s | ReservedNameInvalid before mutation |
| 131 | malformed quarantine | non-hex lowercase byte t | ReservedNameInvalid before mutation |
| 132 | malformed quarantine | non-hex lowercase byte u | ReservedNameInvalid before mutation |
| 133 | malformed quarantine | non-hex lowercase byte v | ReservedNameInvalid before mutation |
| 134 | malformed quarantine | non-hex lowercase byte w | ReservedNameInvalid before mutation |
| 135 | malformed quarantine | non-hex lowercase byte x | ReservedNameInvalid before mutation |
| 136 | malformed quarantine | non-hex lowercase byte y | ReservedNameInvalid before mutation |
| 137 | malformed quarantine | non-hex lowercase byte z | ReservedNameInvalid before mutation |
| 138 | malformed quarantine | control byte 01 after prefix | ReservedNameInvalid before mutation |
| 139 | malformed quarantine | control byte 1f after prefix | ReservedNameInvalid before mutation |
| 140 | malformed quarantine | DEL 7f after prefix | ReservedNameInvalid before mutation |
| 141 | malformed quarantine | invalid UTF-8 byte ff after prefix | ReservedNameInvalid before mutation |
| 142 | malformed quarantine | invalid UTF-8 leading byte 80 after prefix | ReservedNameInvalid before mutation |
| 143 | malformed quarantine | punctuation dash in suffix | ReservedNameInvalid before mutation |
| 144 | malformed quarantine | punctuation underscore in suffix | ReservedNameInvalid before mutation |
| 145 | malformed quarantine | exact 32 hex followed by extra 00-like trailing byte representation | ReservedNameInvalid before mutation |
| 146 | malformed quarantine | exact 32 hex followed by extra ASCII byte | ReservedNameInvalid before mutation |
| 147 | exact quarantine | 00000000000000000000000000000000 | exact prior-process quarantine candidate retained and sorted |
| 148 | exact quarantine | aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa | exact prior-process quarantine candidate retained and sorted |
| 149 | exact quarantine | 0123456789abcdef0123456789abcdef | exact prior-process quarantine candidate retained and sorted |
| 150 | exact quarantine | deadbeefdeadbeefdeadbeefdeadbeef | exact prior-process quarantine candidate retained and sorted |
| 151 | top-level preflight | malformed partial before valid candidate | whole raw scan fails before recursive cleanup or capture begins |
| 152 | top-level preflight | valid candidate before malformed partial | whole raw scan fails before recursive cleanup or capture begins |
| 153 | top-level preflight | malformed quarantine before valid candidate | whole raw scan fails before recursive cleanup or capture begins |
| 154 | top-level preflight | valid candidate before malformed quarantine | whole raw scan fails before recursive cleanup or capture begins |
| 155 | top-level preflight | opaque invalid UTF-8 + valid candidate + malformed reserved | whole raw scan fails before recursive cleanup or capture begins |
| 156 | top-level preflight | 255 opaque candidates and one exact reserved | bounded classification/preflight succeeds without inspecting nonreserved entries |
| 157 | top-level preflight | 256 exact reserved candidates | bounded classification/preflight succeeds without inspecting nonreserved entries |
| 158 | top-level preflight | 257th exact reserved candidate | LimitExceeded before any candidate mutation |
| 159 | top-level preflight | candidate raw name exactly 255 bytes | bounded classification/preflight succeeds without inspecting nonreserved entries |
| 160 | top-level preflight | reserved-prefix name exceeding 255 bytes | ReservedNameInvalid before any candidate mutation |
| 161 | top-level preflight | nonreserved name exceeding 255-byte bound | LimitExceeded before any candidate mutation |
| 162 | strict recursive mode | nested invalid UTF-8 regular file ff | fail closed, preserve evidence, never follow/delete unrepresentable entry |
| 163 | strict recursive mode | nested invalid UTF-8 regular file 80 81 | fail closed, preserve evidence, never follow/delete unrepresentable entry |
| 164 | strict recursive mode | nested control-byte regular file 01 | fail closed, preserve evidence, never follow/delete unrepresentable entry |
| 165 | strict recursive mode | nested DEL-byte regular file 7f | fail closed, preserve evidence, never follow/delete unrepresentable entry |
| 166 | strict recursive mode | nested invalid UTF-8 directory | fail closed, preserve evidence, never follow/delete unrepresentable entry |
| 167 | strict recursive mode | nested control-byte directory | fail closed, preserve evidence, never follow/delete unrepresentable entry |
| 168 | strict recursive mode | nested slash representation | fail closed, preserve evidence, never follow/delete unrepresentable entry |
| 169 | strict recursive mode | nested backslash representation | fail closed, preserve evidence, never follow/delete unrepresentable entry |
| 170 | strict recursive mode | nested dot | fail closed, preserve evidence, never follow/delete unrepresentable entry |
| 171 | strict recursive mode | nested dot-dot | fail closed, preserve evidence, never follow/delete unrepresentable entry |
| 172 | strict recursive mode | nested 256-byte name | fail closed, preserve evidence, never follow/delete unrepresentable entry |
| 173 | strict recursive mode | nested symbolic link | fail closed, preserve evidence, never follow/delete unrepresentable entry |
| 174 | strict recursive mode | nested FIFO | fail closed, preserve evidence, never follow/delete unrepresentable entry |
| 175 | strict recursive mode | nested socket | fail closed, preserve evidence, never follow/delete unrepresentable entry |
| 176 | strict recursive mode | nested device entry | fail closed, preserve evidence, never follow/delete unrepresentable entry |
| 177 | strict recursive mode | nested hard-linked regular file | fail closed, preserve evidence, never follow/delete unrepresentable entry |
| 178 | strict recursive mode | nested setid regular file | fail closed, preserve evidence, never follow/delete unrepresentable entry |
| 179 | strict recursive mode | nested setid directory | fail closed, preserve evidence, never follow/delete unrepresentable entry |
| 180 | strict recursive mode | nested cross-filesystem directory | fail closed, preserve evidence, never follow/delete unrepresentable entry |
| 181 | strict recursive mode | ordinary UTF-8 file | lossless UTF-8 round trip succeeds; existing identity/type safety still applies |
| 182 | strict recursive mode | Unicode café file | lossless UTF-8 round trip succeeds; existing identity/type safety still applies |
| 183 | strict recursive mode | Unicode CJK directory | lossless UTF-8 round trip succeeds; existing identity/type safety still applies |
| 184 | strict recursive mode | nested prior quarantine directory | lossless UTF-8 round trip succeeds; existing identity/type safety still applies |
| 185 | final/post-cleanup scan | no reserved entries remain | successful raw final scan ignores nonreserved entry and retains lock/path validation |
| 186 | final/post-cleanup scan | exact partial remains | CleanupIncomplete because exact reserved evidence remains |
| 187 | final/post-cleanup scan | exact quarantine remains | CleanupIncomplete because exact reserved evidence remains |
| 188 | final/post-cleanup scan | malformed partial remains | ReservedNameInvalid from raw final scan |
| 189 | final/post-cleanup scan | malformed quarantine remains | ReservedNameInvalid from raw final scan |
| 190 | final/post-cleanup scan | opaque invalid UTF-8 remains | successful raw final scan ignores nonreserved entry and retains lock/path validation |
| 191 | final/post-cleanup scan | opaque control-byte name remains | successful raw final scan ignores nonreserved entry and retains lock/path validation |
| 192 | final/post-cleanup scan | published directory remains | successful raw final scan ignores nonreserved entry and retains lock/path validation |
| 193 | final/post-cleanup scan | nonreserved special object remains | successful raw final scan ignores nonreserved entry and retains lock/path validation |
| 194 | post-capture rollback | identity mismatch, rollback proved, no prior mutation | EntryChanged |
| 195 | post-capture rollback | identity mismatch, rollback proved, prior mutation exists | EntryChanged |
| 196 | post-capture rollback | identity mismatch, rollback collision, no prior mutation | RollbackFailed |
| 197 | post-capture rollback | identity mismatch, rollback unprovable, no prior mutation | RollbackFailed |
| 198 | post-capture rollback | identity mismatch, rollback collision after earlier removal | CleanupIncomplete |
| 199 | post-capture rollback | identity mismatch, rollback unprovable after earlier removal | CleanupIncomplete |
| 200 | post-capture rollback | retention length failure, rollback proved, no prior mutation | LimitExceeded |
| 201 | post-capture rollback | retention length failure, rollback proved, prior mutation exists | LimitExceeded |
| 202 | post-capture rollback | retention length failure, rollback collision, no prior mutation | RollbackFailed |
| 203 | post-capture rollback | retention length failure, rollback unprovable, no prior mutation | RollbackFailed |
| 204 | post-capture rollback | retention length failure, rollback collision after mutation | CleanupIncomplete |
| 205 | post-capture rollback | retention length failure, rollback unprovable after mutation | CleanupIncomplete |
| 206 | post-capture rollback | retained-name allocation failure, rollback proved | LimitExceeded |
| 207 | post-capture rollback | retained-name allocation failure, failed first rollback | RollbackFailed |
| 208 | post-capture rollback | retained-name allocation failure, failed rollback after removal | CleanupIncomplete |
| 209 | post-capture rollback | original name recreated before rollback | RollbackFailed before prior mutation; CleanupIncomplete after prior mutation |
| 210 | post-capture rollback | rollback rename EINTR then success | operation-specific EntryChanged or LimitExceeded |
| 211 | post-capture rollback | rollback no-replace collision | preserve both namespaces; RollbackFailed/CleanupIncomplete |
| 212 | post-capture rollback | rollback parent fsync failure | rollback unproved; RollbackFailed/CleanupIncomplete |
| 213 | post-capture rollback | rollback quarantine absence proof failure | rollback unproved; RollbackFailed/CleanupIncomplete |
| 214 | post-capture rollback | rollback original presence proof failure | rollback unproved; RollbackFailed/CleanupIncomplete |
| 215 | post-capture rollback | no overwrite-capable fallback | same RENAME_EXCL helper only |
| 216 | post-capture rollback | failed rollback followed by cleanup caller | capture returns immediately; no unlink/rmdir |
| 217 | atomic cleanup non-regression | exact partial cleanup | preserved from TASK-3.10; exact capture/removal/counter ordering remains |
| 218 | atomic cleanup non-regression | exact prior quarantine cleanup | preserved from TASK-3.10; exact capture/removal/counter ordering remains |
| 219 | atomic cleanup non-regression | multiple raw-sorted candidates | preserved from TASK-3.10; exact capture/removal/counter ordering remains |
| 220 | atomic cleanup non-regression | nested prior-quarantine recovery | preserved from TASK-3.10; exact capture/removal/counter ordering remains |
| 221 | atomic cleanup non-regression | regular-file capture before unlink | preserved from TASK-3.10; exact capture/removal/counter ordering remains |
| 222 | atomic cleanup non-regression | regular-file quarantine identity proof | preserved from TASK-3.10; exact capture/removal/counter ordering remains |
| 223 | atomic cleanup non-regression | regular-file nlink-zero proof | preserved from TASK-3.10; exact capture/removal/counter ordering remains |
| 224 | atomic cleanup non-regression | regular-file parent fsync before counter | preserved from TASK-3.10; exact capture/removal/counter ordering remains |
| 225 | atomic cleanup non-regression | subdirectory recursive cleanup | preserved from TASK-3.10; exact capture/removal/counter ordering remains |
| 226 | atomic cleanup non-regression | subdirectory empty rescan | preserved from TASK-3.10; exact capture/removal/counter ordering remains |
| 227 | atomic cleanup non-regression | subdirectory capture before rmdir | preserved from TASK-3.10; exact capture/removal/counter ordering remains |
| 228 | atomic cleanup non-regression | subdirectory parent fsync before counter | preserved from TASK-3.10; exact capture/removal/counter ordering remains |
| 229 | atomic cleanup non-regression | root lock validation before cleanup | preserved from TASK-3.10; exact capture/removal/counter ordering remains |
| 230 | atomic cleanup non-regression | root empty rescan and strict sync | preserved from TASK-3.10; exact capture/removal/counter ordering remains |
| 231 | atomic cleanup non-regression | root capture before rmdir | preserved from TASK-3.10; exact capture/removal/counter ordering remains |
| 232 | atomic cleanup non-regression | root original/quarantine absence proof | preserved from TASK-3.10; exact capture/removal/counter ordering remains |
| 233 | atomic cleanup non-regression | root bundle fsync before counters | preserved from TASK-3.10; exact capture/removal/counter ordering remains |
| 234 | atomic cleanup non-regression | removedEntryCount increments only after durability | preserved from TASK-3.10; exact capture/removal/counter ordering remains |
| 235 | atomic cleanup non-regression | cleanedWorkspaceCount increments only after durability | preserved from TASK-3.10; exact capture/removal/counter ordering remains |
| 236 | atomic cleanup non-regression | no stale entries succeeds | preserved from TASK-3.10; exact capture/removal/counter ordering remains |
| 237 | atomic cleanup non-regression | one-shot cleanup second call | preserved from TASK-3.10; exact capture/removal/counter ordering remains |
| 238 | atomic cleanup non-regression | final lock ownership validation | preserved from TASK-3.10; exact capture/removal/counter ordering remains |
| 239 | atomic cleanup non-regression | final canonical bundle path validation | preserved from TASK-3.10; exact capture/removal/counter ordering remains |
| 240 | atomic cleanup non-regression | published backup never selected | preserved from TASK-3.10; exact capture/removal/counter ordering remains |
| 241 | atomic cleanup non-regression | legacy root never mutated | preserved from TASK-3.10; exact capture/removal/counter ordering remains |
| 242 | protected foundation | PXBackupDirectoryDiscovery.h byte identity | before/after SHA-256 and byte size match; protected Git diff is empty |
| 243 | protected foundation | PXBackupDirectoryDiscovery.m byte identity | before/after SHA-256 and byte size match; protected Git diff is empty |
| 244 | protected foundation | PXBackupStaleWorkspaceCleanup.h byte identity | before/after SHA-256 and byte size match; protected Git diff is empty |
| 245 | protected foundation | AppDataBackupManager.h byte identity | before/after SHA-256 and byte size match; protected Git diff is empty |
| 246 | protected foundation | AppDataBackupManager.m byte identity | before/after SHA-256 and byte size match; protected Git diff is empty |
| 247 | protected foundation | PXBackupFailureCleanup.h/.m byte identity | before/after SHA-256 and byte size match; protected Git diff is empty |
| 248 | protected foundation | PXBackupPublicationWorkspace.h/.m byte identity | before/after SHA-256 and byte size match; protected Git diff is empty |
| 249 | protected foundation | PXBackupBundleLock.h/.m byte identity | before/after SHA-256 and byte size match; protected Git diff is empty |
| 250 | protected foundation | PXBackupArtifactPolicy.h/.m byte identity | before/after SHA-256 and byte size match; protected Git diff is empty |
| 251 | protected foundation | PXBackupArtifactWriter.h/.m byte identity | before/after SHA-256 and byte size match; protected Git diff is empty |
| 252 | protected foundation | PXBackupManifestV4.h/.m byte identity | before/after SHA-256 and byte size match; protected Git diff is empty |
| 253 | protected foundation | PXBackupManifestValidator.h/.m byte identity | before/after SHA-256 and byte size match; protected Git diff is empty |
| 254 | protected foundation | PXBackupManifestWriter.h/.m byte identity | before/after SHA-256 and byte size match; protected Git diff is empty |
| 255 | protected foundation | PXBackupDirectoryPublisher.h/.m byte identity | before/after SHA-256 and byte size match; protected Git diff is empty |
| 256 | protected foundation | artifact/archive validators byte identity | before/after SHA-256 and byte size match; protected Git diff is empty |
| 257 | protected foundation | Restore plan/transaction/staging/resolver byte identity | before/after SHA-256 and byte size match; protected Git diff is empty |
| 258 | protected foundation | CommandRunner byte identity | before/after SHA-256 and byte size match; protected Git diff is empty |
| 259 | protected foundation | Makefile byte identity | before/after SHA-256 and byte size match; protected Git diff is empty |
| 260 | protected foundation | UI/controller byte identity | before/after SHA-256 and byte size match; protected Git diff is empty |
| 261 | protected foundation | Keychain helper/bridge/script byte identity | before/after SHA-256 and byte size match; protected Git diff is empty |
| 262 | protected foundation | coordinator artifacts untouched and unstaged | before/after SHA-256 and byte size match; protected Git diff is empty |
## Protected production SHA-256 and byte size before/after
The table covers every tracked non-document production/config/runtime file except the single authorized production source. Hashes use the same workspace-byte representation before and after; Git protected diff is independently empty.

| File | Before SHA-256 | Before bytes | After SHA-256 | After bytes | Match |
|---|---|---:|---|---:|---:|
| `.DS_Store` | `f4f3698d1ec6f68d7e09216183fe633be14d588a3f41f247b437bf03cf1228e1` | 14340 | `f4f3698d1ec6f68d7e09216183fe633be14d588a3f41f247b437bf03cf1228e1` | 14340 | TRUE |
| `Agent.md` | `23a29d59fac7fc30d40b6a7c8387d0413d90d400fba88fbafb515476ba317336` | 6521 | `23a29d59fac7fc30d40b6a7c8387d0413d90d400fba88fbafb515476ba317336` | 6521 | TRUE |
| `AppDataBackupManager.h` | `b19c1c61e6df642468d713dede5a0c0bd0dbb6a0ac72d98ad6878d3cae1f2e75` | 1442 | `b19c1c61e6df642468d713dede5a0c0bd0dbb6a0ac72d98ad6878d3cae1f2e75` | 1442 | TRUE |
| `AppDataBackupManager.m` | `d6a302c90ab988a2c9b27c36fa664bc219082c6175f631942426b5fb91d2191e` | 221835 | `d6a302c90ab988a2c9b27c36fa664bc219082c6175f631942426b5fb91d2191e` | 221835 | TRUE |
| `AppDataBackupRestoreViewController.h` | `b470e92a732dca1c97b161f802baf1d3ea8d39706087648e7fc697b63eeba5cf` | 336 | `b470e92a732dca1c97b161f802baf1d3ea8d39706087648e7fc697b63eeba5cf` | 336 | TRUE |
| `AppDataBackupRestoreViewController.m` | `48e86f63aeeb6626858fe13fed6487ef36e128f0f0fde173120abb9108bd7a96` | 28132 | `48e86f63aeeb6626858fe13fed6487ef36e128f0f0fde173120abb9108bd7a96` | 28132 | TRUE |
| `AppDataCleaner.h` | `b32a62280c2df60a33658e7ec9193b76802d989c984c42193f045a94365c915e` | 4768 | `b32a62280c2df60a33658e7ec9193b76802d989c984c42193f045a94365c915e` | 4768 | TRUE |
| `AppDataCleaner.m` | `69549666233bbbd812f16ba5abae9bfa875e5d85723a2a8f82d63b54332d4c93` | 370484 | `69549666233bbbd812f16ba5abae9bfa875e5d85723a2a8f82d63b54332d4c93` | 370484 | TRUE |
| `AppEntitlementsReader.h` | `c3baaeee968e61283f2e6e76ad04855815db9e8872a1814cd449d177c692e94e` | 1061 | `c3baaeee968e61283f2e6e76ad04855815db9e8872a1814cd449d177c692e94e` | 1061 | TRUE |
| `AppEntitlementsReader.m` | `0b53c3e24caaff5db6ceee2ae89e85ac8d4c7a7fa826cfbe814ef62c56448797` | 11626 | `0b53c3e24caaff5db6ceee2ae89e85ac8d4c7a7fa826cfbe814ef62c56448797` | 11626 | TRUE |
| `AppGroupContainerResolver.h` | `c18f6e6dd09d19dd49564d442c956eb3be4a153118faff392cdd899846263c97` | 1356 | `c18f6e6dd09d19dd49564d442c956eb3be4a153118faff392cdd899846263c97` | 1356 | TRUE |
| `AppGroupContainerResolver.m` | `11646d96beec86f070ea49e0a803fb1bc669bc48af56135f1acd7c39a5439df1` | 11499 | `11646d96beec86f070ea49e0a803fb1bc669bc48af56135f1acd7c39a5439df1` | 11499 | TRUE |
| `AppVersionManager.h` | `bab65a2d67128d4dd4b2ee061214f0732d1335928a7e599d469a707e4c59ecd2` | 1295 | `bab65a2d67128d4dd4b2ee061214f0732d1335928a7e599d469a707e4c59ecd2` | 1295 | TRUE |
| `AppVersionManager.m` | `2096f05e3c5d53947ce4dfdc08e3d9015af96441719c455f74944cd8615afd91` | 15049 | `2096f05e3c5d53947ce4dfdc08e3d9015af96441719c455f74944cd8615afd91` | 15049 | TRUE |
| `AppVersionSpoofingViewController.h` | `011c95fb8f776d6fae961faa94d1b0ff63bc3a1d81a0b222db9d2db8f81bbb1d` | 678 | `011c95fb8f776d6fae961faa94d1b0ff63bc3a1d81a0b222db9d2db8f81bbb1d` | 678 | TRUE |
| `AppVersionSpoofingViewController.m` | `04e55427fc60c91c3a87a3a780161078b1ff643728e3bf8c4bc9ad3ac0eff6ed` | 85181 | `04e55427fc60c91c3a87a3a780161078b1ff643728e3bf8c4bc9ad3ac0eff6ed` | 85181 | TRUE |
| `Assets.xcassets/.DS_Store` | `dd93a4f43f346f9e8065cbfb6c3fb69910f2f284de52be4db2cfb2444895390a` | 6148 | `dd93a4f43f346f9e8065cbfb6c3fb69910f2f284de52be4db2cfb2444895390a` | 6148 | TRUE |
| `Assets.xcassets/AppIcon.appiconset/114.png` | `166c1096529e278504a87b29a4d38d2e0161bc204d2d040b9ad8609d4fc7a50f` | 8495 | `166c1096529e278504a87b29a4d38d2e0161bc204d2d040b9ad8609d4fc7a50f` | 8495 | TRUE |
| `Assets.xcassets/AppIcon.appiconset/120.png` | `6dc938664f361ba919f2c77e6b0b576e73151a687f46144022345cb8261c34b2` | 9368 | `6dc938664f361ba919f2c77e6b0b576e73151a687f46144022345cb8261c34b2` | 9368 | TRUE |
| `Assets.xcassets/AppIcon.appiconset/180.png` | `6ca7f490751306e8f228bfcfc2fe75bddd348c68e37286b9830915c8e559efc0` | 17711 | `6ca7f490751306e8f228bfcfc2fe75bddd348c68e37286b9830915c8e559efc0` | 17711 | TRUE |
| `Assets.xcassets/AppIcon.appiconset/29.png` | `744b7d04bb3fc1a604aab8e0c226db5511e57e836eac3ae19f9393f5dc579d51` | 1323 | `744b7d04bb3fc1a604aab8e0c226db5511e57e836eac3ae19f9393f5dc579d51` | 1323 | TRUE |
| `Assets.xcassets/AppIcon.appiconset/40.png` | `009124d0d893d71e2e9a131acbbc2d8a60dc260d743bdda73d4009b948039fa1` | 2181 | `009124d0d893d71e2e9a131acbbc2d8a60dc260d743bdda73d4009b948039fa1` | 2181 | TRUE |
| `Assets.xcassets/AppIcon.appiconset/57.png` | `800c14a931ca8b7b6b2a5bdf6514d982e190e1ce62313e3ec928ef1a485e4e13` | 3277 | `800c14a931ca8b7b6b2a5bdf6514d982e190e1ce62313e3ec928ef1a485e4e13` | 3277 | TRUE |
| `Assets.xcassets/AppIcon.appiconset/58.png` | `cca475fd7868d52db5451b870d1451a4ecc4d742f86c7b57a64ee9da16ae42d5` | 3350 | `cca475fd7868d52db5451b870d1451a4ecc4d742f86c7b57a64ee9da16ae42d5` | 3350 | TRUE |
| `Assets.xcassets/AppIcon.appiconset/60.png` | `89074f9c04cfc686b1522ec7be34d2cd6a2d378b948747ae1d5945a9fe056d5f` | 3536 | `89074f9c04cfc686b1522ec7be34d2cd6a2d378b948747ae1d5945a9fe056d5f` | 3536 | TRUE |
| `Assets.xcassets/AppIcon.appiconset/80.png` | `413476ef167e7507abca272e00adfe6654fed084f82b22a67df41e9eae28b883` | 5273 | `413476ef167e7507abca272e00adfe6654fed084f82b22a67df41e9eae28b883` | 5273 | TRUE |
| `Assets.xcassets/AppIcon.appiconset/87.png` | `72e90989084a130368405d67a6be27aef16014bb1c06a2dbb0f6afe4470a16b7` | 5820 | `72e90989084a130368405d67a6be27aef16014bb1c06a2dbb0f6afe4470a16b7` | 5820 | TRUE |
| `Assets.xcassets/AppIcon.appiconset/Contents.json` | `eb58f836a1ae5cdb9b42d5f6877f76ba678bf7310ffe1e0478bb39530c7425f6` | 1655 | `eb58f836a1ae5cdb9b42d5f6877f76ba678bf7310ffe1e0478bb39530c7425f6` | 1655 | TRUE |
| `Assets.xcassets/AppIcon.appiconset/Thumbs.db` | `d8108e4360bcc91b08e0ea8699131d923ea32bda8672a5ea5095c20b8afecf5f` | 3584 | `d8108e4360bcc91b08e0ea8699131d923ea32bda8672a5ea5095c20b8afecf5f` | 3584 | TRUE |
| `BackupKeychainGroupsViewController.h` | `fc77d536ab2a573b598ac7ff72339a63229d68f15ae239b827cb4dd2a78c2377` | 159 | `fc77d536ab2a573b598ac7ff72339a63229d68f15ae239b827cb4dd2a78c2377` | 159 | TRUE |
| `BackupKeychainGroupsViewController.m` | `2f0590d7b51b05733f92c9df19c93953c2ab14fc8ca7380c43b4126ea60c4ccf` | 9567 | `2f0590d7b51b05733f92c9df19c93953c2ab14fc8ca7380c43b4126ea60c4ccf` | 9567 | TRUE |
| `BottomButtons.h` | `1c31f5cf5e62bda2cd580d9c7b1b2471a1218e6d8c1c330ae081c9081c49d325` | 849 | `1c31f5cf5e62bda2cd580d9c7b1b2471a1218e6d8c1c330ae081c9081c49d325` | 849 | TRUE |
| `BottomButtons.m` | `025c32bfcdc79f5c81c0ad6d93be0bc1ba02f797b56a44ed62e915c62e26536b` | 24605 | `025c32bfcdc79f5c81c0ad6d93be0bc1ba02f797b56a44ed62e915c62e26536b` | 24605 | TRUE |
| `CommandRunner.h` | `63b88cf788fa8c981419f2c36f9375d1ed6e55190143c3c4e16b0972fe1d52bf` | 1562 | `63b88cf788fa8c981419f2c36f9375d1ed6e55190143c3c4e16b0972fe1d52bf` | 1562 | TRUE |
| `CommandRunner.m` | `2d5d68cd307ab150d85a28db69dd5a6169c40f78b3eb6fe49468bdaae2475030` | 49583 | `2d5d68cd307ab150d85a28db69dd5a6169c40f78b3eb6fe49468bdaae2475030` | 49583 | TRUE |
| `ContainerManager.h` | `d1c5ac27362d01b91fee79e6c963e23d52eb1b0b4ee22d9030f9c7d1495e78c1` | 1109 | `d1c5ac27362d01b91fee79e6c963e23d52eb1b0b4ee22d9030f9c7d1495e78c1` | 1109 | TRUE |
| `ContainerManager.m` | `f49a397e9c1c9122f3cfcfbabda6932b3864f2dbd2855e702b7913c2318bece9` | 4393 | `f49a397e9c1c9122f3cfcfbabda6932b3864f2dbd2855e702b7913c2318bece9` | 4393 | TRUE |
| `CopyHelper.h` | `d318b6795e3d11414e8e79e0d15441b46dd9e34f7ce88e42d4809635bee786d9` | 531 | `d318b6795e3d11414e8e79e0d15441b46dd9e34f7ce88e42d4809635bee786d9` | 531 | TRUE |
| `CopyHelper.m` | `67ef46d464cb4a1abc839b97aaaefd6ae259a9858f0b46ac062bb396848abbc1` | 6147 | `67ef46d464cb4a1abc839b97aaaefd6ae259a9858f0b46ac062bb396848abbc1` | 6147 | TRUE |
| `DEBIAN/postinst` | `672605bb1f4db0ab20e7a9ed08741597ec89f91a5d19be04ddca12ba75024a72` | 4119 | `672605bb1f4db0ab20e7a9ed08741597ec89f91a5d19be04ddca12ba75024a72` | 4119 | TRUE |
| `DEBIAN/preinst` | `c5da98965be1131bb53af46b1f4ab17be0fa45aba9881550c3c6f497bba9e30e` | 198 | `c5da98965be1131bb53af46b1f4ab17be0fa45aba9881550c3c6f497bba9e30e` | 198 | TRUE |
| `DEBIAN/prerm` | `cf8dbdff236c16a3e219a18e9a28a24370781d4315821da45c26c53f94ab22d6` | 126 | `cf8dbdff236c16a3e219a18e9a28a24370781d4315821da45c26c53f94ab22d6` | 126 | TRUE |
| `DeviceSpecificSpoofingViewController+EditLabel.h` | `1cda7513c54b5af56a8ab8faa015c529cdb723597ae22e1f6949ebff72653369` | 161 | `1cda7513c54b5af56a8ab8faa015c529cdb723597ae22e1f6949ebff72653369` | 161 | TRUE |
| `DeviceSpecificSpoofingViewController+EditLabel.m` | `eb54be2f1c94b9656ebdd52e5b9bae4f9284d369bcaa223384fa490a2cbb8929` | 9198 | `eb54be2f1c94b9656ebdd52e5b9bae4f9284d369bcaa223384fa490a2cbb8929` | 9198 | TRUE |
| `DeviceSpecificSpoofingViewController+ProfileManagerDelegate.m` | `51dfdb0f30cb3208cd8375903f986f9597b82d34e2d9c969751238e3dd4ff63c` | 508 | `51dfdb0f30cb3208cd8375903f986f9597b82d34e2d9c969751238e3dd4ff63c` | 508 | TRUE |
| `DeviceSpecificSpoofingViewController.h` | `6c7d28b87e0a0dc009a4394a074aff539a1a2e5c799811b038c3e91400cb4ef4` | 134 | `6c7d28b87e0a0dc009a4394a074aff539a1a2e5c799811b038c3e91400cb4ef4` | 134 | TRUE |
| `DeviceSpecificSpoofingViewController.m` | `403624616748a13ff669e885cfe646145a05dab71a612ace675180ebc41d3ef2` | 56660 | `403624616748a13ff669e885cfe646145a05dab71a612ace675180ebc41d3ef2` | 56660 | TRUE |
| `DevicesViewController.h` | `6722488756616f27394308ea0c8e6399bc71c5200ccb3421a603682ccd8329e5` | 1160 | `6722488756616f27394308ea0c8e6399bc71c5200ccb3421a603682ccd8329e5` | 1160 | TRUE |
| `DevicesViewController.m` | `79cf759ccae76beb2ba3cbb5a90ff3a8e7f239fee97748fd019bbd499f4a6e8a` | 38275 | `79cf759ccae76beb2ba3cbb5a90ff3a8e7f239fee97748fd019bbd499f4a6e8a` | 38275 | TRUE |
| `DomainManagementViewController.h` | `558250c37d54ba9de744c00fa625f127cead096de1e073356837abb1f2e7aa4f` | 112 | `558250c37d54ba9de744c00fa625f127cead096de1e073356837abb1f2e7aa4f` | 112 | TRUE |
| `DomainManagementViewController.m` | `304191541ce30d76ca68b4bf134fabc9db4a9df63b8bafefb90ceaf41a93d66d` | 30905 | `304191541ce30d76ca68b4bf134fabc9db4a9df63b8bafefb90ceaf41a93d66d` | 30905 | TRUE |
| `DoorDashOrderViewController.h` | `c381a89fb9cad521fd8ccd2492a6ff9592223f631cabf82c7b0701a8d10f7eab` | 668 | `c381a89fb9cad521fd8ccd2492a6ff9592223f631cabf82c7b0701a8d10f7eab` | 668 | TRUE |
| `DoorDashOrderViewController.m` | `1fa89a2df85125dba4de371c28febf138179cfc188e45894853a49a08c09d4a3` | 37685 | `1fa89a2df85125dba4de371c28febf138179cfc188e45894853a49a08c09d4a3` | 37685 | TRUE |
| `DownloadResourcesViewController.h` | `4106923a6377598b9a40a214b99c799a69a8cb25959ffe9cc23f9b0af55b342f` | 96 | `4106923a6377598b9a40a214b99c799a69a8cb25959ffe9cc23f9b0af55b342f` | 96 | TRUE |
| `DownloadResourcesViewController.m` | `c561ea7c67518b62bf2e91cdcd11c6dd1540f881e1d7887aa3ebe4bc81670deb` | 2456 | `c561ea7c67518b62bf2e91cdcd11c6dd1540f881e1d7887aa3ebe4bc81670deb` | 2456 | TRUE |
| `FileManagerViewController.h` | `3434af2ed0adfb193198757611ca465792442b0b76dfa4d48d7e3e2b7c0abf64` | 658 | `3434af2ed0adfb193198757611ca465792442b0b76dfa4d48d7e3e2b7c0abf64` | 658 | TRUE |
| `FileManagerViewController.m` | `bb2a6f965ede7581ab658d7300e0d76ce8b96ce1bc83236ae2a7dff9a5728887` | 55902 | `bb2a6f965ede7581ab658d7300e0d76ce8b96ce1bc83236ae2a7dff9a5728887` | 55902 | TRUE |
| `FixVersionAppsViewController.h` | `d62d7097d8c958218b12354802b4af74f3ca0ae23f95056f1cae6f323adfb749` | 93 | `d62d7097d8c958218b12354802b4af74f3ca0ae23f95056f1cae6f323adfb749` | 93 | TRUE |
| `FixVersionAppsViewController.m` | `c7b82233db03c7d29ae5640228ec987e80f75a1d4fe3805348c43d02e9072cf5` | 7764 | `c7b82233db03c7d29ae5640228ec987e80f75a1d4fe3805348c43d02e9072cf5` | 7764 | TRUE |
| `FreezeManager.h` | `bdf75483157b774cca85e65c5e93bee581a8ef6be0f5f378070e04d26f43b894` | 385 | `bdf75483157b774cca85e65c5e93bee581a8ef6be0f5f378070e04d26f43b894` | 385 | TRUE |
| `FreezeManager.m` | `00473a0fab8fda61235b66058152697b68a60deff46a3f8d4b209bb3574845c4` | 8975 | `00473a0fab8fda61235b66058152697b68a60deff46a3f8d4b209bb3574845c4` | 8975 | TRUE |
| `Icon.png` | `6dc938664f361ba919f2c77e6b0b576e73151a687f46144022345cb8261c34b2` | 9368 | `6dc938664f361ba919f2c77e6b0b576e73151a687f46144022345cb8261c34b2` | 9368 | TRUE |
| `Improvement_Plan.md` | `6707b1154da25fb64f56380146a0172ec1d2e4d22d4242a90a81f953252a67c3` | 12526 | `6707b1154da25fb64f56380146a0172ec1d2e4d22d4242a90a81f953252a67c3` | 12526 | TRUE |
| `Info.plist` | `2d017f405d32126d2102999838a77984a5c7bffc39be728ed479487cd903f477` | 7202 | `2d017f405d32126d2102999838a77984a5c7bffc39be728ed479487cd903f477` | 7202 | TRUE |
| `KeychainGroupsViewController.h` | `48945d11fbf9ee4e9921140fc7d674abacbed3076db2b514fc641b6ac118a50b` | 153 | `48945d11fbf9ee4e9921140fc7d674abacbed3076db2b514fc641b6ac118a50b` | 153 | TRUE |
| `KeychainGroupsViewController.m` | `0e25b51199550964a5f743e50dc49641d161efd347973d49f58cc861a6260d35` | 10227 | `0e25b51199550964a5f743e50dc49641d161efd347973d49f58cc861a6260d35` | 10227 | TRUE |
| `KeychainHelper/KeychainBackupHelper.h` | `dbf0d5a4bdfc1df3e4f74b103968e018d0932f89c245bae8f260b196c0664281` | 4280 | `dbf0d5a4bdfc1df3e4f74b103968e018d0932f89c245bae8f260b196c0664281` | 4280 | TRUE |
| `KeychainHelper/KeychainBackupHelper.m` | `203884bf8d009a01a936acb5371c9316f7a0d6212b0d226f7f8a7661d51d122c` | 27970 | `203884bf8d009a01a936acb5371c9316f7a0d6212b0d226f7f8a7661d51d122c` | 27970 | TRUE |
| `KeychainHelper/backup_helper.m` | `9f4e2c1cd0d7ebb7afef93d537e759858d60d2ae2ddd89b7b535ec611d437b83` | 14129 | `9f4e2c1cd0d7ebb7afef93d537e759858d60d2ae2ddd89b7b535ec611d437b83` | 14129 | TRUE |
| `LaunchScreen.storyboard` | `36cf5911aab28984a57eecb7544336636bd75a763961075505be9720bd1f23bb` | 3134 | `36cf5911aab28984a57eecb7544336636bd75a763961075505be9720bd1f23bb` | 3134 | TRUE |
| `Makefile` | `717465ec5894548e894412aa7f4205f4b8d5ac7e9d13339327477dd686d6c9a9` | 9146 | `717465ec5894548e894412aa7f4205f4b8d5ac7e9d13339327477dd686d6c9a9` | 9146 | TRUE |
| `Making` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 | TRUE |
| `MatrixRainView.h` | `8a82ddcdcb831793821158d219feafef052540c09ecead96a29d6c63fe2ca94c` | 273 | `8a82ddcdcb831793821158d219feafef052540c09ecead96a29d6c63fe2ca94c` | 273 | TRUE |
| `Newplan.md` | `d2f5a2d387bd4e513f9981f6071b889c3ff723043d2c661ccebe7bafc55df204` | 17391 | `d2f5a2d387bd4e513f9981f6071b889c3ff723043d2c661ccebe7bafc55df204` | 17391 | TRUE |
| `PXAppGroupRestoreTargetPlan.h` | `565924464aafb15836a4506de0336f62c2eb0986f7fa7ebd1839d98c48e888d3` | 2039 | `565924464aafb15836a4506de0336f62c2eb0986f7fa7ebd1839d98c48e888d3` | 2039 | TRUE |
| `PXAppGroupRestoreTargetPlan.m` | `c03b64aa48b59ff1fb380ff8fcfb0b6aba468739921fe7b151e8d8445bc8731d` | 18688 | `c03b64aa48b59ff1fb380ff8fcfb0b6aba468739921fe7b151e8d8445bc8731d` | 18688 | TRUE |
| `PXAppGroupRestoreTransaction.h` | `cd329b3f67433214b36d195719e337cc951204c774dd65bbe379eb8936a33412` | 2235 | `cd329b3f67433214b36d195719e337cc951204c774dd65bbe379eb8936a33412` | 2235 | TRUE |
| `PXAppGroupRestoreTransaction.m` | `842bf9676fdac4c31433f966b81b2b93c82d03225d7f046d7e464a3b402bfbd6` | 138376 | `842bf9676fdac4c31433f966b81b2b93c82d03225d7f046d7e464a3b402bfbd6` | 138376 | TRUE |
| `PXBackupArchiveValidator.h` | `661258274d798bfd67356d472334cfffcc1da6a911278ae6e956a66e0cf4b05b` | 2361 | `661258274d798bfd67356d472334cfffcc1da6a911278ae6e956a66e0cf4b05b` | 2361 | TRUE |
| `PXBackupArchiveValidator.m` | `01c8c628453b8f67853a84ebf9c5511c6a9af454c80bc476da1d9f685eaa306e` | 89098 | `01c8c628453b8f67853a84ebf9c5511c6a9af454c80bc476da1d9f685eaa306e` | 89098 | TRUE |
| `PXBackupArtifactPolicy.h` | `52da8d6a0537d6a9647af13b9a992d5e131d6405f3ea2759f6a811b7ad90f80f` | 1648 | `52da8d6a0537d6a9647af13b9a992d5e131d6405f3ea2759f6a811b7ad90f80f` | 1648 | TRUE |
| `PXBackupArtifactPolicy.m` | `c40df7376b918cadf79508a9cb45aa04bf27390e015e80e442a41764be13f7bc` | 4536 | `c40df7376b918cadf79508a9cb45aa04bf27390e015e80e442a41764be13f7bc` | 4536 | TRUE |
| `PXBackupArtifactVerifier.h` | `6831f6fd7b52eda12d6407c744e8f4fe5b3fcf101567185930ce53246da9c7a0` | 1949 | `6831f6fd7b52eda12d6407c744e8f4fe5b3fcf101567185930ce53246da9c7a0` | 1949 | TRUE |
| `PXBackupArtifactVerifier.m` | `81a828d3d3365430a308ccf7e8ca655a5efa5496d97caae936ebc1fa303701f1` | 43911 | `81a828d3d3365430a308ccf7e8ca655a5efa5496d97caae936ebc1fa303701f1` | 43911 | TRUE |
| `PXBackupArtifactWriter.h` | `5e91f6db0b8921f6980e4db53eb06edf2b505be05eacc16334bca6f7a80bb1e8` | 2948 | `5e91f6db0b8921f6980e4db53eb06edf2b505be05eacc16334bca6f7a80bb1e8` | 2948 | TRUE |
| `PXBackupArtifactWriter.m` | `0362e20b17155d1182b528779c749bd23ffa4614436e03231a8c3e1ac9b4f330` | 83333 | `0362e20b17155d1182b528779c749bd23ffa4614436e03231a8c3e1ac9b4f330` | 83333 | TRUE |
| `PXBackupBundleLock.h` | `6a094c91f862db366d2bb976d889645971dd72f7a1781a027df9d205318c2ce9` | 1714 | `6a094c91f862db366d2bb976d889645971dd72f7a1781a027df9d205318c2ce9` | 1714 | TRUE |
| `PXBackupBundleLock.m` | `563cb607b41ba12e6620b7a8a72e999a84715fd64b671555d512e8440798613b` | 36342 | `563cb607b41ba12e6620b7a8a72e999a84715fd64b671555d512e8440798613b` | 36342 | TRUE |
| `PXBackupDirectoryDiscovery.h` | `da0b54991b39159de122169227f28827f6fde2375c1fe52ff9c47902143d2df2` | 1708 | `da0b54991b39159de122169227f28827f6fde2375c1fe52ff9c47902143d2df2` | 1708 | TRUE |
| `PXBackupDirectoryDiscovery.m` | `f7380363790e5fbc896f64b3b9c2b325361ec26745196c2874cc1b1d153448c5` | 38228 | `f7380363790e5fbc896f64b3b9c2b325361ec26745196c2874cc1b1d153448c5` | 38228 | TRUE |
| `PXBackupDirectoryPublisher.h` | `014be6af62da52efab0f442d93814a88634953dbc56ae38d24f932d873834e39` | 2889 | `014be6af62da52efab0f442d93814a88634953dbc56ae38d24f932d873834e39` | 2889 | TRUE |
| `PXBackupDirectoryPublisher.m` | `0f85750abf3ef1f2043be5af8708f340cccb20606188b09f63843cc5963d8223` | 70795 | `0f85750abf3ef1f2043be5af8708f340cccb20606188b09f63843cc5963d8223` | 70795 | TRUE |
| `PXBackupFailureCleanup.h` | `ee242afc8ca4aad39dcfe240e168bcc4d52e72abb63a835981f306c71f89466d` | 2377 | `ee242afc8ca4aad39dcfe240e168bcc4d52e72abb63a835981f306c71f89466d` | 2377 | TRUE |
| `PXBackupFailureCleanup.m` | `669ac9cc24489cb388058afd54d8fd63e28057220fa2ea9020aa93431e8d3138` | 80668 | `669ac9cc24489cb388058afd54d8fd63e28057220fa2ea9020aa93431e8d3138` | 80668 | TRUE |
| `PXBackupManifestV4.h` | `4e9c679d8d4a69f68111bb848467a7290a8760330b310ef4c2a25941612e6054` | 2354 | `4e9c679d8d4a69f68111bb848467a7290a8760330b310ef4c2a25941612e6054` | 2354 | TRUE |
| `PXBackupManifestV4.m` | `db7e09ceeee46049ff180e88293e6088b652b8ae1c231ad2c3ec825cd5bd9fd7` | 44234 | `db7e09ceeee46049ff180e88293e6088b652b8ae1c231ad2c3ec825cd5bd9fd7` | 44234 | TRUE |
| `PXBackupManifestValidator.h` | `6bf479c032e044a89a9d028517a50692c7d95ccef35f78e92a782653a4dcc836` | 945 | `6bf479c032e044a89a9d028517a50692c7d95ccef35f78e92a782653a4dcc836` | 945 | TRUE |
| `PXBackupManifestValidator.m` | `e3403920f816cbf6c8c1c135d835786fa83f56a36901a9e41427e86cf6bb1820` | 91751 | `e3403920f816cbf6c8c1c135d835786fa83f56a36901a9e41427e86cf6bb1820` | 91751 | TRUE |
| `PXBackupManifestWriter.h` | `a8eef3991f2e9176d0ddd73aa007c7e2442be6b2e257b6576dfa5db680a2f546` | 2431 | `a8eef3991f2e9176d0ddd73aa007c7e2442be6b2e257b6576dfa5db680a2f546` | 2431 | TRUE |
| `PXBackupManifestWriter.m` | `005c64ea37718f3c8c4a0ac97422441bb5e1393d7cfe8082aecd1e14d519729c` | 54069 | `005c64ea37718f3c8c4a0ac97422441bb5e1393d7cfe8082aecd1e14d519729c` | 54069 | TRUE |
| `PXBackupPublicationWorkspace.h` | `7ee3ce30d84edd6907cdc9fd3fb812dd768d03decb3ee0d50d464d17c4ae0851` | 1869 | `7ee3ce30d84edd6907cdc9fd3fb812dd768d03decb3ee0d50d464d17c4ae0851` | 1869 | TRUE |
| `PXBackupPublicationWorkspace.m` | `39974a40b4bf89f31ac9cbf1e8dfa716a94a0fd13e39d9c7539a02d14d2781f6` | 48086 | `39974a40b4bf89f31ac9cbf1e8dfa716a94a0fd13e39d9c7539a02d14d2781f6` | 48086 | TRUE |
| `PXBackupStaleWorkspaceCleanup.h` | `82cdc1e356907c75e9e04b39de6ff81809bd50cb0fd265d2683d865444cba76d` | 2265 | `82cdc1e356907c75e9e04b39de6ff81809bd50cb0fd265d2683d865444cba76d` | 2265 | TRUE |
| `PXClearRequest.h` | `d87402ee3720f1723977e4deb3d78bc1de87362948dfe585b5ed98f6447ae26b` | 1288 | `d87402ee3720f1723977e4deb3d78bc1de87362948dfe585b5ed98f6447ae26b` | 1288 | TRUE |
| `PXClearRequest.m` | `afc763afc3306d422ef67ef3bd28a2a1a5741a64ea6078ee28f56f5d5901c790` | 4389 | `afc763afc3306d422ef67ef3bd28a2a1a5741a64ea6078ee28f56f5d5901c790` | 4389 | TRUE |
| `PXClearResult.h` | `cedc6e364ebc4bf25acd8d128938db114033ca076750d2fade8e183488b2b592` | 3467 | `cedc6e364ebc4bf25acd8d128938db114033ca076750d2fade8e183488b2b592` | 3467 | TRUE |
| `PXClearResult.m` | `0e4bce039d6ca19f46590822bdfc938763cddc852be3045f6ada98e2fa0c5715` | 10564 | `0e4bce039d6ca19f46590822bdfc938763cddc852be3045f6ada98e2fa0c5715` | 10564 | TRUE |
| `PXDataContainerResolver.h` | `b2e10dc045d49d9d09e0055973885b576f9909896dd8778339e65e0e812b8f30` | 1290 | `b2e10dc045d49d9d09e0055973885b576f9909896dd8778339e65e0e812b8f30` | 1290 | TRUE |
| `PXDataContainerResolver.m` | `cc29adca6dc2fb30354541fdec9992b7cf7450d6cc0470c46864ecf456b4a365` | 8332 | `cc29adca6dc2fb30354541fdec9992b7cf7450d6cc0470c46864ecf456b4a365` | 8332 | TRUE |
| `PXDestructivePathValidator.h` | `542e158a4f04bf50125e0064fbebf02ac32f1de07508c3f32058e770f75a3c0a` | 1213 | `542e158a4f04bf50125e0064fbebf02ac32f1de07508c3f32058e770f75a3c0a` | 1213 | TRUE |
| `PXDestructivePathValidator.m` | `f275a60be5cab58e5d06db3dd0987948f5eab65ddd7e35e35e45927d238877cb` | 32523 | `f275a60be5cab58e5d06db3dd0987948f5eab65ddd7e35e35e45927d238877cb` | 32523 | TRUE |
| `PXMainDataRestoreTransaction.h` | `df444b03e0214d62e31c89094f7e0afe1037255ab6582928a608ec839466a575` | 2061 | `df444b03e0214d62e31c89094f7e0afe1037255ab6582928a608ec839466a575` | 2061 | TRUE |
| `PXMainDataRestoreTransaction.m` | `894c40ab599074bc6c481a5b9084c3d557c64fb101336f0495d5297234a5f3c5` | 115847 | `894c40ab599074bc6c481a5b9084c3d557c64fb101336f0495d5297234a5f3c5` | 115847 | TRUE |
| `PXMainDataStaging.h` | `2eaea45c166986c419b32074141e8e1f7ab6000f153e860b10b48e1405620554` | 2511 | `2eaea45c166986c419b32074141e8e1f7ab6000f153e860b10b48e1405620554` | 2511 | TRUE |
| `PXMainDataStaging.m` | `686fbbf5c382b9c2dfc4f5917b20993cca434a1976f098f20f98ddfa87769162` | 67751 | `686fbbf5c382b9c2dfc4f5917b20993cca434a1976f098f20f98ddfa87769162` | 67751 | TRUE |
| `PXOptionalRestoreStaging.h` | `b412a77d26f4e22d17083f4faa761d0dc02c4fef8e25f5aec4c2c84be86a78e4` | 4209 | `b412a77d26f4e22d17083f4faa761d0dc02c4fef8e25f5aec4c2c84be86a78e4` | 4209 | TRUE |
| `PXOptionalRestoreStaging.m` | `639333e3f891ee6e61cb1f486c97e54c68751439c64014c03169c37a2ea8e3f5` | 100980 | `639333e3f891ee6e61cb1f486c97e54c68751439c64014c03169c37a2ea8e3f5` | 100980 | TRUE |
| `PXOptionalRestoreTransaction.h` | `1d162e411824a708209c78325385cff75cea453a8097c93347f02cfb8bf2ad78` | 4050 | `1d162e411824a708209c78325385cff75cea453a8097c93347f02cfb8bf2ad78` | 4050 | TRUE |
| `PXOptionalRestoreTransaction.m` | `b766f73f7b49877ab589f35ae9dc7d0f89e80638526e6c5663777ac6a1a48c1c` | 240408 | `b766f73f7b49877ab589f35ae9dc7d0f89e80638526e6c5663777ac6a1a48c1c` | 240408 | TRUE |
| `PXResolvedContainer.h` | `6ba935cb659ebdc5fdb8a96b13dd9f1450acb2e284267ac82e8890287a686718` | 1691 | `6ba935cb659ebdc5fdb8a96b13dd9f1450acb2e284267ac82e8890287a686718` | 1691 | TRUE |
| `PXResolvedContainer.m` | `a782089c0605f8d7803ffb53f746a585afb85f3ffbc9ed111f00575d77ada8fb` | 5304 | `a782089c0605f8d7803ffb53f746a585afb85f3ffbc9ed111f00575d77ada8fb` | 5304 | TRUE |
| `PXRestorePlan.h` | `5cc773132c009fd8eedf4069b33ab53901a530edd580e3231c9d982c60cf7643` | 4947 | `5cc773132c009fd8eedf4069b33ab53901a530edd580e3231c9d982c60cf7643` | 4947 | TRUE |
| `PXRestorePlan.m` | `cb6f838638a06bc9858b392d123656590291555812c63e3d0ddd4f5529d0d141` | 48523 | `cb6f838638a06bc9858b392d123656590291555812c63e3d0ddd4f5529d0d141` | 48523 | TRUE |
| `PXRestoreResult.h` | `cb7f2f3e40b3414d329405b1802bf6a9f245f1b660ca983d04776c0af449e69d` | 4512 | `cb7f2f3e40b3414d329405b1802bf6a9f245f1b660ca983d04776c0af449e69d` | 4512 | TRUE |
| `PXRestoreResult.m` | `c698a854589731f0987379c324d02729f3b586fd0ac3575f9798b77d6207c2fb` | 15842 | `c698a854589731f0987379c324d02729f3b586fd0ac3575f9798b77d6207c2fb` | 15842 | TRUE |
| `PlistViewerViewController.h` | `84e7faeb8986573e038eb4ccd89ad69096be5bbb668c28d21701964dce1d9861` | 184 | `84e7faeb8986573e038eb4ccd89ad69096be5bbb668c28d21701964dce1d9861` | 184 | TRUE |
| `PlistViewerViewController.m` | `204b5483da9c6605dd7bce780f32841f5f578a5f808cec9043dcd6158a57b5b1` | 26767 | `204b5483da9c6605dd7bce780f32841f5f578a5f808cec9043dcd6158a57b5b1` | 26767 | TRUE |
| `ProfileButtonsView.h` | `f684b1fd6790fcf3484195c7115441c435bcfcb0a376f8a9dcec79f71a9dcc44` | 254 | `f684b1fd6790fcf3484195c7115441c435bcfcb0a376f8a9dcec79f71a9dcc44` | 254 | TRUE |
| `ProfileButtonsView.m` | `d4f7db76a846f87a5bbeda0a3360244e56a6c6da77ea38607386c62d29c92d8b` | 5381 | `d4f7db76a846f87a5bbeda0a3360244e56a6c6da77ea38607386c62d29c92d8b` | 5381 | TRUE |
| `ProfileCreationViewController.h` | `9a0607d0f92ac497b86435e5abdd3402f5f68e900893130a084f777e7b5429b6` | 388 | `9a0607d0f92ac497b86435e5abdd3402f5f68e900893130a084f777e7b5429b6` | 388 | TRUE |
| `ProfileCreationViewController.m` | `3899ba590c6d4e222e7516c1fcfc0947c84a28f2439c84f92cefaaf9a61d4f60` | 7575 | `3899ba590c6d4e222e7516c1fcfc0947c84a28f2439c84f92cefaaf9a61d4f60` | 7575 | TRUE |
| `ProfileManagerViewController.h` | `d96f5b92633c1aad6ed40a6e007aa9c00e69b4b9fe7209c0ea0502c5d5b7a2f4` | 783 | `d96f5b92633c1aad6ed40a6e007aa9c00e69b4b9fe7209c0ea0502c5d5b7a2f4` | 783 | TRUE |
| `ProfileManagerViewController.m` | `a26680aa7340f00b913950cd019245066d0854880839403346a965fbf832bb1a` | 159713 | `a26680aa7340f00b913950cd019245066d0854880839403346a965fbf832bb1a` | 159713 | TRUE |
| `ProgressHUDView.h` | `b02f257178fbb9b705ba19f49d37528126d100b968ef1bf9f91f9312c94eb8d5` | 522 | `b02f257178fbb9b705ba19f49d37528126d100b968ef1bf9f91f9312c94eb8d5` | 522 | TRUE |
| `ProgressHUDView.m` | `18f60d3321c26d692e27310e8e1ef334b99a2cd8daa732234623d17006aabb98` | 2263 | `18f60d3321c26d692e27310e8e1ef334b99a2cd8daa732234623d17006aabb98` | 2263 | TRUE |
| `ProjectX` | `a81b074d511a8a7c94032dabd27feb7cdf43585788e559b2858b934dd2224c9e` | 1691136 | `a81b074d511a8a7c94032dabd27feb7cdf43585788e559b2858b934dd2224c9e` | 1691136 | TRUE |
| `ProjectX.entitlements` | `224bece3b1e28d417a1b9c1f70c82aa1453d8af9562e0bc3298279aec4dc459c` | 1747 | `224bece3b1e28d417a1b9c1f70c82aa1453d8af9562e0bc3298279aec4dc459c` | 1747 | TRUE |
| `ProjectX.h` | `5dcd27265018819afb50b9b4d2582563f9048c773e9ced1ce7a1833d44f8fb03` | 1623 | `5dcd27265018819afb50b9b4d2582563f9048c773e9ced1ce7a1833d44f8fb03` | 1623 | TRUE |
| `ProjectXInstaller.h` | `9b7d06a8a0687e36187b838d9b9acd7ccc66e04d49ea97565fc924e7ea361245` | 1231 | `9b7d06a8a0687e36187b838d9b9acd7ccc66e04d49ea97565fc924e7ea361245` | 1231 | TRUE |
| `ProjectXInstaller.m` | `5f2d464b5f7c00c4c83a849a8a2783ed54868e9ff8290a7283824309e993b41b` | 1898 | `5f2d464b5f7c00c4c83a849a8a2783ed54868e9ff8290a7283824309e993b41b` | 1898 | TRUE |
| `ProjectXSceneDelegate.h` | `2e56a5014cde4c047575638be864e83e2560da885aa25a5ecb150f05b3525f5f` | 192 | `2e56a5014cde4c047575638be864e83e2560da885aa25a5ecb150f05b3525f5f` | 192 | TRUE |
| `ProjectXSceneDelegate.m` | `dc056734ec81ff57484ef2e2ddddda9496b39d774ff743c42cfa6e88bbb0677e` | 12181 | `dc056734ec81ff57484ef2e2ddddda9496b39d774ff743c42cfa6e88bbb0677e` | 12181 | TRUE |
| `ProjectXTweak.dylib` | `e024784ca18867a8eb9924a7342da693c6fccb8af97716446a611db13dc8b171` | 945152 | `e024784ca18867a8eb9924a7342da693c6fccb8af97716446a611db13dc8b171` | 945152 | TRUE |
| `ProjectXTweak.plist` | `9c8559c83f6fa8a4e247caf92265adbbbe65cb4d2cdadd2fa594de4700fff2f8` | 429 | `9c8559c83f6fa8a4e247caf92265adbbbe65cb4d2cdadd2fa594de4700fff2f8` | 429 | TRUE |
| `ProjectXTweak/AAA_TestCtor.m` | `3226080d60eec3c92a9966f09c4adc12b58b4211329e2106a4db460333c36b70` | 1614 | `3226080d60eec3c92a9966f09c4adc12b58b4211329e2106a4db460333c36b70` | 1614 | TRUE |
| `ProjectXTweak/AppContainerHooks.x` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 | TRUE |
| `ProjectXTweak/AppGroupHooks.x` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 | TRUE |
| `ProjectXTweak/AppInstallHooks.x` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 | TRUE |
| `ProjectXTweak/AppVersionHooks.h` | `7010216dcf52c45952a5ac3be1211db49952d46f76a4ee9d98a323a4c864b96a` | 546 | `7010216dcf52c45952a5ac3be1211db49952d46f76a4ee9d98a323a4c864b96a` | 546 | TRUE |
| `ProjectXTweak/AppVersionHooks.x` | `091eda3e306a0fcb5a0889d09d3af11fe491edd1d6acf5c6ca076adc069ee992` | 25202 | `091eda3e306a0fcb5a0889d09d3af11fe491edd1d6acf5c6ca076adc069ee992` | 25202 | TRUE |
| `ProjectXTweak/BatteryHooks.x` | `cda2451306704f7be1b8e228dea3818a661869fc2951f9bb13ed17d97e04a462` | 17019 | `cda2451306704f7be1b8e228dea3818a661869fc2951f9bb13ed17d97e04a462` | 17019 | TRUE |
| `ProjectXTweak/BootTimeHooks.x` | `1cf9ff3f8930a12ce53a809aa2c5e3dc8ce648836a882692f0bb2999214aedc9` | 26933 | `1cf9ff3f8930a12ce53a809aa2c5e3dc8ce648836a882692f0bb2999214aedc9` | 26933 | TRUE |
| `ProjectXTweak/CanvasFingerprintHooks.x` | `8d58697627269d9329490050de59d2d22409bbaadf462e85e16fbb3fa2a160f5` | 27600 | `8d58697627269d9329490050de59d2d22409bbaadf462e85e16fbb3fa2a160f5` | 27600 | TRUE |
| `ProjectXTweak/CoreDataHooks.x` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 | TRUE |
| `ProjectXTweak/DeviceModelHooks.x` | `0523ea3f49d45037a14e319477efb936f22c049582600a649b79765a88618313` | 9012 | `0523ea3f49d45037a14e319477efb936f22c049582600a649b79765a88618313` | 9012 | TRUE |
| `ProjectXTweak/DeviceSpecHooks.x` | `4cc3bf32980902c66eac012b23b5bc9f3ece2efb6606a84140b99a3827a94e27` | 81702 | `4cc3bf32980902c66eac012b23b5bc9f3ece2efb6606a84140b99a3827a94e27` | 81702 | TRUE |
| `ProjectXTweak/DomainBlockingHooks.x` | `43130baab0454d4c0be7515b6454ba14ea1aa8327d112f15ad2d87de00999d9b` | 27065 | `43130baab0454d4c0be7515b6454ba14ea1aa8327d112f15ad2d87de00999d9b` | 27065 | TRUE |
| `ProjectXTweak/FirebasePerfDisableScoped.x` | `a361527514d0de6fef9bb14552f7e753dccc3a1a3ce7010302d68884d85ec844` | 2515 | `a361527514d0de6fef9bb14552f7e753dccc3a1a3ce7010302d68884d85ec844` | 2515 | TRUE |
| `ProjectXTweak/HookOwnership.h` | `7a35059699c35fd433bbc588d1cfc7e240b4447268e9ecc94a400ae3cfd4d2da` | 541 | `7a35059699c35fd433bbc588d1cfc7e240b4447268e9ecc94a400ae3cfd4d2da` | 541 | TRUE |
| `ProjectXTweak/IOSVersionHooks.x` | `bc3a7d9f7fc848399d90cf1321bcf132708f71263a2c7c509d9b20304b4fb860` | 112809 | `bc3a7d9f7fc848399d90cf1321bcf132708f71263a2c7c509d9b20304b4fb860` | 112809 | TRUE |
| `ProjectXTweak/JailbreakBypassHooks.x` | `989c720f92a03470a7bba9ce60f2a7b341f7a538a924a41a8ee47304da373494` | 142382 | `989c720f92a03470a7bba9ce60f2a7b341f7a538a924a41a8ee47304da373494` | 142382 | TRUE |
| `ProjectXTweak/KeychainHooks.x` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 | TRUE |
| `ProjectXTweak/LocaleTimeZoneHooks.x` | `853fe8689c3e8173aba8d4e3b34e67fd5e3b99ea35f34cf6cf1eb2f376b215c8` | 4909 | `853fe8689c3e8173aba8d4e3b34e67fd5e3b99ea35f34cf6cf1eb2f376b215c8` | 4909 | TRUE |
| `ProjectXTweak/Makefile.bak` | `b509097c737be4b6eff89ff01f49cd3b690d9217e89b304be17718b1c61ec018` | 999 | `b509097c737be4b6eff89ff01f49cd3b690d9217e89b304be17718b1c61ec018` | 999 | TRUE |
| `ProjectXTweak/MethodSwizzler.h` | `bf42638563a47092e76e95296d999b7bb440b2d98095957aff83a8d3c69f810e` | 341 | `bf42638563a47092e76e95296d999b7bb440b2d98095957aff83a8d3c69f810e` | 341 | TRUE |
| `ProjectXTweak/MethodSwizzler.m` | `39a9324dd2fa8590f25d61b3e8f106cef5acea7d0f2784c4ab1b2f919b52e982` | 1903 | `39a9324dd2fa8590f25d61b3e8f106cef5acea7d0f2784c4ab1b2f919b52e982` | 1903 | TRUE |
| `ProjectXTweak/MissingSpoofHooks.x` | `ed71e70219a2e4fdc42f6cf1930bee71c83c0a565741f5afdd7ec7752c0508e1` | 9793 | `ed71e70219a2e4fdc42f6cf1930bee71c83c0a565741f5afdd7ec7752c0508e1` | 9793 | TRUE |
| `ProjectXTweak/MobileGestalt.h` | `a81ba122e63f9ebb143a65afa8227badd76cfd7b971fe7ee5e9aab77c8b6352b` | 11371 | `a81ba122e63f9ebb143a65afa8227badd76cfd7b971fe7ee5e9aab77c8b6352b` | 11371 | TRUE |
| `ProjectXTweak/NetworkConnectionTypeHooks.x` | `445e68b2a745e17922842fb620c080d83f73dc002e460b362b2e0fdf8ae487db` | 56573 | `445e68b2a745e17922842fb620c080d83f73dc002e460b362b2e0fdf8ae487db` | 56573 | TRUE |
| `ProjectXTweak/ObjcClassPairGuard.x` | `8d009928b014571c0aec433aac908936989e24fe848e01b38fa1b83991487ad9` | 5439 | `8d009928b014571c0aec433aac908936989e24fe848e01b38fa1b83991487ad9` | 5439 | TRUE |
| `ProjectXTweak/PXFileDebug.h` | `0ff94999994a071b66a1482d3b97bdacc4f31002096129b661243a774dd1bcc5` | 6957 | `0ff94999994a071b66a1482d3b97bdacc4f31002096129b661243a774dd1bcc5` | 6957 | TRUE |
| `ProjectXTweak/PXNativeHookCoordinator.h` | `248f78c9bc54e625d540e9ae8c3a7a4021e05fdac0a43830b669cb4dcfa625e4` | 9000 | `248f78c9bc54e625d540e9ae8c3a7a4021e05fdac0a43830b669cb4dcfa625e4` | 9000 | TRUE |
| `ProjectXTweak/PXNativeHookCoordinator.m` | `2ad1f7fc4b46e59ec6e4776a4eb5d9b8331da41c1fdf4b73860eabd37d4ff27d` | 28291 | `2ad1f7fc4b46e59ec6e4776a4eb5d9b8331da41c1fdf4b73860eabd37d4ff27d` | 28291 | TRUE |
| `ProjectXTweak/PXScope.h` | `4ebc18511d27845a0a14499406d2525cde6c32043a931857c057521222638b32` | 1747 | `4ebc18511d27845a0a14499406d2525cde6c32043a931857c057521222638b32` | 1747 | TRUE |
| `ProjectXTweak/PXScope.m` | `46193b6d6b3443b8b879a8e8b32b4f18ee3a4072134e4965957091fa6a4ce44f` | 20405 | `46193b6d6b3443b8b879a8e8b32b4f18ee3a4072134e4965957091fa6a4ce44f` | 20405 | TRUE |
| `ProjectXTweak/PasteboardHooks.x` | `2a158ee64def29488c10a78bebe7a66b07ad5b3a9e4ad8122599ea8e204cfe19` | 37855 | `2a158ee64def29488c10a78bebe7a66b07ad5b3a9e4ad8122599ea8e204cfe19` | 37855 | TRUE |
| `ProjectXTweak/SpringBoardLaunchHook.x` | `04b3a6f8caffae072b0bd4c7adf1f2dc5f6ef0d8772da6fcefa570e8d3dc2d55` | 16185 | `04b3a6f8caffae072b0bd4c7adf1f2dc5f6ef0d8772da6fcefa570e8d3dc2d55` | 16185 | TRUE |
| `ProjectXTweak/StorageHooks.x` | `315d3887f0f2aa3fc59b9b7aa5ef6b0a72e63ce248dd78097b85545f6434297a` | 41482 | `315d3887f0f2aa3fc59b9b7aa5ef6b0a72e63ce248dd78097b85545f6434297a` | 41482 | TRUE |
| `ProjectXTweak/ThemeHooks.x` | `3c8be122460f652f2c15f5737ab3ae96c44ff1391658191659301adfcc27c4cf` | 19043 | `3c8be122460f652f2c15f5737ab3ae96c44ff1391658191659301adfcc27c4cf` | 19043 | TRUE |
| `ProjectXTweak/Tweak.x` | `a8dfc1055e1973b7fe2b9f3320a754de63e4ea887e6ca5c836924f5af5bdf82f` | 196955 | `a8dfc1055e1973b7fe2b9f3320a754de63e4ea887e6ca5c836924f5af5bdf82f` | 196955 | TRUE |
| `ProjectXTweak/UUIDHooks.x` | `90b86d384da2c0c8cb2593ff40eff3ff5831e3ae481034888ace50cfd3d05a7d` | 43164 | `90b86d384da2c0c8cb2593ff40eff3ff5831e3ae481034888ace50cfd3d05a7d` | 43164 | TRUE |
| `ProjectXTweak/UberURLHooks.x` | `be5123cbfb9971807329e9d97fb881d30ac55550e68b6ba769c4da9b7f69001b` | 40212 | `be5123cbfb9971807329e9d97fb881d30ac55550e68b6ba769c4da9b7f69001b` | 40212 | TRUE |
| `ProjectXTweak/UserDefaultsHooks.x` | `ad6076166b161d35c82cd1418fca4d72f98df87bc5e2a46812830d21edfd6154` | 26089 | `ad6076166b161d35c82cd1418fca4d72f98df87bc5e2a46812830d21edfd6154` | 26089 | TRUE |
| `ProjectXTweak/VPNDetectionBypass.x` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 | TRUE |
| `ProjectXTweak/WiFiHook.x` | `045c84ad29aad9520de43d8bf9c4967132c83ecee239c30f9240807fa9f5c36b` | 40848 | `045c84ad29aad9520de43d8bf9c4967132c83ecee239c30f9240807fa9f5c36b` | 40848 | TRUE |
| `ProjectXViewController.h` | `046a37c9ccfc33c7a46ddefd74369abfa08b8b96712093f2bffcf3e8bae8fa1c` | 853 | `046a37c9ccfc33c7a46ddefd74369abfa08b8b96712093f2bffcf3e8bae8fa1c` | 853 | TRUE |
| `ProjectXViewController.m` | `b7c5293dfa5d27fdc39c36f236f76306a855eaaf4e9e028f4c2111eb68146162` | 372278 | `b7c5293dfa5d27fdc39c36f236f76306a855eaaf4e9e028f4c2111eb68146162` | 372278 | TRUE |
| `README.md` | `de0e61f9ee6cb9ac61e0db218ae510cf9fcc0bd84ec8f0229e76c7ed3117a0d2` | 184 | `de0e61f9ee6cb9ac61e0db218ae510cf9fcc0bd84ec8f0229e76c7ed3117a0d2` | 184 | TRUE |
| `SecurityTabViewController+IPMonitorInfo.m` | `d389a7c50f1bd2fc14761d72db0c86bda7fae1d931ed9143f0a1c1ecbec57121` | 967 | `d389a7c50f1bd2fc14761d72db0c86bda7fae1d931ed9143f0a1c1ecbec57121` | 967 | TRUE |
| `SecurityTabViewController.h` | `7f21e86f58fe5377f2964fba785ae65dde5e89284aca8aca334ea5322190f53d` | 5441 | `7f21e86f58fe5377f2964fba785ae65dde5e89284aca8aca334ea5322190f53d` | 5441 | TRUE |
| `SecurityTabViewController.m` | `9a3629b4751b6c9f1dee227a66ff61a57b8cbeed7c13b4e81dc63b314f4acbaf` | 293431 | `9a3629b4751b6c9f1dee227a66ff61a57b8cbeed7c13b4e81dc63b314f4acbaf` | 293431 | TRUE |
| `TabBarController+DeviceAlerts.h` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 | TRUE |
| `TabBarController+DeviceAlerts.m` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 | TRUE |
| `TabBarController.h` | `f71b771e6e94a716f3678744b80fef317baafd33198292fb45b16ebd022b8584` | 1019 | `f71b771e6e94a716f3678744b80fef317baafd33198292fb45b16ebd022b8584` | 1019 | TRUE |
| `TabBarController.m` | `09f8f74232728fb8edd4c699cf612683d04aff6bc1fdfd766970e65e7829d2eb` | 28147 | `09f8f74232728fb8edd4c699cf612683d04aff6bc1fdfd766970e65e7829d2eb` | 28147 | TRUE |
| `TestCtorTweak/Makefile` | `acce9155e79d225a6b892aa7b85bb33696bd6d22eed356cc4add4a0dac7de85c` | 217 | `acce9155e79d225a6b892aa7b85bb33696bd6d22eed356cc4add4a0dac7de85c` | 217 | TRUE |
| `TestCtorTweak/TestCtorTweak.plist` | `c84e26f2c423b89c5f84cf847b9132079de48bbef72b1f7d8ebe96370796d61f` | 315 | `c84e26f2c423b89c5f84cf847b9132079de48bbef72b1f7d8ebe96370796d61f` | 315 | TRUE |
| `TestCtorTweak/Tweak.x` | `17219fd435a7dce5cf70f59eca6a21c7f950f9e3f68578c0e560e7e16bb07924` | 351 | `17219fd435a7dce5cf70f59eca6a21c7f950f9e3f68578c0e560e7e16bb07924` | 351 | TRUE |
| `ToolViewController.h` | `8b182a81a023731502ab0be3bef0076733a94fde71077486df8424c46ec01ba0` | 280 | `8b182a81a023731502ab0be3bef0076733a94fde71077486df8424c46ec01ba0` | 280 | TRUE |
| `ToolViewController.m` | `46413d0c6777a0afa4df06ddcb8c10da30b9114b3e6a6db4e1abbaae3c191a2e` | 59814 | `46413d0c6777a0afa4df06ddcb8c10da30b9114b3e6a6db4e1abbaae3c191a2e` | 59814 | TRUE |
| `URLMonitor.h` | `2897113b7a6e98f40c72d13ccce718c289420d38199939d43a0bd76ada7caaac` | 727 | `2897113b7a6e98f40c72d13ccce718c289420d38199939d43a0bd76ada7caaac` | 727 | TRUE |
| `URLMonitor.m` | `34f764be70ac6fa679f729489550556f5bc49785086932260d03b243d875be59` | 8827 | `34f764be70ac6fa679f729489550556f5bc49785086932260d03b243d875be59` | 8827 | TRUE |
| `UberOrderViewController.h` | `ed4f5e3011738de767e791813f2adc8a1c2fc970f115ab3c30ce3fcfab8c99e6` | 608 | `ed4f5e3011738de767e791813f2adc8a1c2fc970f115ab3c30ce3fcfab8c99e6` | 608 | TRUE |
| `UberOrderViewController.m` | `5d14235cbcc59a246d82e213f8824defdebe62ba8737ca54d7a554ff69253931` | 39801 | `5d14235cbcc59a246d82e213f8824defdebe62ba8737ca54d7a554ff69253931` | 39801 | TRUE |
| `VersionManagementViewController.h` | `5b262b3cec01fd6e030efc25672424f8a64b49d2c1ac7e3f54a32f1a959acbb2` | 955 | `5b262b3cec01fd6e030efc25672424f8a64b49d2c1ac7e3f54a32f1a959acbb2` | 955 | TRUE |
| `VersionManagementViewController.m` | `68a33b786e2aea4999b07e37e4801c97e188be0b0dfc876da89e20403cff25ae` | 68330 | `68a33b786e2aea4999b07e37e4801c97e188be0b0dfc876da89e20403cff25ae` | 68330 | TRUE |
| `WeaponXGuardian.m` | `47db55dc74fe96ec3ae731843d7cbc8e0cbd9c647103a8cb797b7281e433f10b` | 16859 | `47db55dc74fe96ec3ae731843d7cbc8e0cbd9c647103a8cb797b7281e433f10b` | 16859 | TRUE |
| `WeaponXKeychainBridge.plist` | `e47d3b6c67ff941c9232d1fcf643bd94e81327cfd40244f1b5f38b99b918fe02` | 386 | `e47d3b6c67ff941c9232d1fcf643bd94e81327cfd40244f1b5f38b99b918fe02` | 386 | TRUE |
| `WeaponXKeychainBridge/Tweak.m` | `e0733e04eb4915a4753fe59247b17acd5e8cb7f8fa5fcf0bb8dee94f908459aa` | 21970 | `e0733e04eb4915a4753fe59247b17acd5e8cb7f8fa5fcf0bb8dee94f908459aa` | 21970 | TRUE |
| `WeaponXMountDaemon/WeaponXDaemon.m` | `c9ba6d287f3743ce3aab7b76615f864d72f32404fa2d3ce85b2ebb0b3cf9dcb3` | 19900 | `c9ba6d287f3743ce3aab7b76615f864d72f32404fa2d3ce85b2ebb0b3cf9dcb3` | 19900 | TRUE |
| `WeaponXMountDaemon/WeaponXMountDaemon.m` | `30e9e71ba449199e2140e798d6e7b3e35e2f66710dc1bed2c70933af7af04a0f` | 11205 | `30e9e71ba449199e2140e798d6e7b3e35e2f66710dc1bed2c70933af7af04a0f` | 11205 | TRUE |
| `WebKit_Filtering.md` | `17e394e126e548a068785f0ab05a383726590e3f8e2ae99a285bc655c13a8c22` | 5499 | `17e394e126e548a068785f0ab05a383726590e3f8e2ae99a285bc655c13a8c22` | 5499 | TRUE |
| `com.hydra.weaponx.guardian.plist` | `713d7975fdedef0abb50e3207e34a9fbaedd241ec417174ebdd59fc2a6126f68` | 1145 | `713d7975fdedef0abb50e3207e34a9fbaedd241ec417174ebdd59fc2a6126f68` | 1145 | TRUE |
| `common/AppContainerUUIDManager.h` | `4ce1170d8f576bc9ae7da4a5a52faebf3f2a986ba66ad06561085270436ad9ac` | 542 | `4ce1170d8f576bc9ae7da4a5a52faebf3f2a986ba66ad06561085270436ad9ac` | 542 | TRUE |
| `common/AppContainerUUIDManager.m` | `623df4a811358a3c897a1420c7f3fc6a72bcff1457540821a9e6db5524d05e55` | 3559 | `623df4a811358a3c897a1420c7f3fc6a72bcff1457540821a9e6db5524d05e55` | 3559 | TRUE |
| `common/AppGroupUUIDManager.h` | `dc28577f1bc5cade1942f4d9a646690fa20cf60544983238dfe0f2fff0c914af` | 406 | `dc28577f1bc5cade1942f4d9a646690fa20cf60544983238dfe0f2fff0c914af` | 406 | TRUE |
| `common/AppGroupUUIDManager.m` | `e5597aecbda830fbc8373103ca68f4674a07231370a7a94b4d1ba78b16dc9355` | 3449 | `e5597aecbda830fbc8373103ca68f4674a07231370a7a94b4d1ba78b16dc9355` | 3449 | TRUE |
| `common/AppInstallUUIDManager.h` | `5af466057f85afaa59470dde8b576acc056f899246c207b79b91c0557c427c0c` | 532 | `5af466057f85afaa59470dde8b576acc056f899246c207b79b91c0557c427c0c` | 532 | TRUE |
| `common/AppInstallUUIDManager.m` | `da9a3156ea08238c60a75c334bb328b13f81eeae876e996f22d8446cab8f66a3` | 3539 | `da9a3156ea08238c60a75c334bb328b13f81eeae876e996f22d8446cab8f66a3` | 3539 | TRUE |
| `common/BatteryManager.h` | `24eb8739f4d31c5b70d49393a14e3633cf56c1c5babb99bdab108fa5cb0a6430` | 685 | `24eb8739f4d31c5b70d49393a14e3633cf56c1c5babb99bdab108fa5cb0a6430` | 685 | TRUE |
| `common/BatteryManager.m` | `77b12c45676efe1ce826a282ebe8bc5949ee5349d7405bf719ff6decebce5d26` | 13918 | `77b12c45676efe1ce826a282ebe8bc5949ee5349d7405bf719ff6decebce5d26` | 13918 | TRUE |
| `common/CarrierDB.h` | `b6696746582b7e687e4fe9ac3eb7dc20e3fdac74574b7e0834d6d08180ce4e32` | 1418 | `b6696746582b7e687e4fe9ac3eb7dc20e3fdac74574b7e0834d6d08180ce4e32` | 1418 | TRUE |
| `common/CarrierDB.m` | `a4ec03f2cceba3675db17b20024e867b8ffae39c55bba1b9591774c7f56b168e` | 12622 | `a4ec03f2cceba3675db17b20024e867b8ffae39c55bba1b9591774c7f56b168e` | 12622 | TRUE |
| `common/CoreDataUUIDManager.h` | `892e127ae63e1f47374dfb112f85932ae02ddc1ded28ec15f0e109bd7554fd1d` | 422 | `892e127ae63e1f47374dfb112f85932ae02ddc1ded28ec15f0e109bd7554fd1d` | 422 | TRUE |
| `common/CoreDataUUIDManager.m` | `21f09a12da71e74b703bced4c7a9c4ef8fed1a2046824c8200510ee677045c85` | 3450 | `21f09a12da71e74b703bced4c7a9c4ef8fed1a2046824c8200510ee677045c85` | 3450 | TRUE |
| `common/DBDebugLogger.h` | `d3a600284f4f0bb5969eb39576b05432263e138fa1f0ab47ea393ee2d02fd714` | 262 | `d3a600284f4f0bb5969eb39576b05432263e138fa1f0ab47ea393ee2d02fd714` | 262 | TRUE |
| `common/DBDebugLogger.m` | `c10cb0af16fe8e67187b6f9de6697a1e0f949dd6af03d8e69774eed946e92f42` | 2783 | `c10cb0af16fe8e67187b6f9de6697a1e0f949dd6af03d8e69774eed946e92f42` | 2783 | TRUE |
| `common/DeviceModelManager.h` | `fa94aa68e6de07ee7c7697fbfc88f30e929377a35b5083cf106af386a6a67865` | 1697 | `fa94aa68e6de07ee7c7697fbfc88f30e929377a35b5083cf106af386a6a67865` | 1697 | TRUE |
| `common/DeviceModelManager.m` | `2837317f930529299573cb37bd225a131f0cde10c01463c14631024dd3ffd5ab` | 37928 | `2837317f930529299573cb37bd225a131f0cde10c01463c14631024dd3ffd5ab` | 37928 | TRUE |
| `common/DeviceNameManager.h` | `0383dab0d4f5890e5f157abbdaf3c1a97b43373716768e1eb6699a80602c838c` | 385 | `0383dab0d4f5890e5f157abbdaf3c1a97b43373716768e1eb6699a80602c838c` | 385 | TRUE |
| `common/DeviceNameManager.m` | `ce19316a6f3ee82166ce1d7867213bd108d1d5d1406b8ecd9fb0fe3ec4cba029` | 11474 | `ce19316a6f3ee82166ce1d7867213bd108d1d5d1406b8ecd9fb0fe3ec4cba029` | 11474 | TRUE |
| `common/DomainBlockingSettings.h` | `2892eb655c23d45ea40c8ee5e11815e941af7552b54cb573ad6953bfb01e1823` | 882 | `2892eb655c23d45ea40c8ee5e11815e941af7552b54cb573ad6953bfb01e1823` | 882 | TRUE |
| `common/DomainBlockingSettings.m` | `b1e043159a2841c65795d3074cda14194b3b4a83a3fb5cd3652725b65abd132a` | 12424 | `b1e043159a2841c65795d3074cda14194b3b4a83a3fb5cd3652725b65abd132a` | 12424 | TRUE |
| `common/DyldCacheUUIDManager.h` | `984684afea3a133454c4518855930d546e5caea4fefacaf5b3eedfc78f062025` | 411 | `984684afea3a133454c4518855930d546e5caea4fefacaf5b3eedfc78f062025` | 411 | TRUE |
| `common/DyldCacheUUIDManager.m` | `54f3a2087ef4f2f1d4116682733b19eb753f1e2ed1b0fbb8e75b8cb4cb208562` | 3458 | `54f3a2087ef4f2f1d4116682733b19eb753f1e2ed1b0fbb8e75b8cb4cb208562` | 3458 | TRUE |
| `common/IDFAManager.h` | `1dfa1d1f301419031727e3b1ec35dbb8cfb6ca1286e683663df6efe7bfcff1a1` | 335 | `1dfa1d1f301419031727e3b1ec35dbb8cfb6ca1286e683663df6efe7bfcff1a1` | 335 | TRUE |
| `common/IDFAManager.m` | `7c0f5d758c886bc5bc38f9a800063c5bd223eeb745a823ac4a514a215c2c9a41` | 2745 | `7c0f5d758c886bc5bc38f9a800063c5bd223eeb745a823ac4a514a215c2c9a41` | 2745 | TRUE |
| `common/IDFVManager.h` | `0b4f9c2198d5ab9fe2b4935561f051efb120d7ba65d784fdafab42ef51751b29` | 335 | `0b4f9c2198d5ab9fe2b4935561f051efb120d7ba65d784fdafab42ef51751b29` | 335 | TRUE |
| `common/IDFVManager.m` | `a1504d870759b9dcbeb2d3a65a4e3e2befe79b2af684702894c217bc34e0f7f6` | 2712 | `a1504d870759b9dcbeb2d3a65a4e3e2befe79b2af684702894c217bc34e0f7f6` | 2712 | TRUE |
| `common/IOSBuildDB.h` | `a5c31abe50dce78944fbb8229122d86c21445bd5b96cbab4ca5a9a9ff6160654` | 1092 | `a5c31abe50dce78944fbb8229122d86c21445bd5b96cbab4ca5a9a9ff6160654` | 1092 | TRUE |
| `common/IOSBuildDB.m` | `234aff3926a0b702f4d47d7b3df8b565d2f304c8035abb127a8c1480bba704e4` | 9567 | `234aff3926a0b702f4d47d7b3df8b565d2f304c8035abb127a8c1480bba704e4` | 9567 | TRUE |
| `common/IOSVersionInfo.h` | `6e34a51759ad38bd05669b69932a1119ca84cf284203ca3deefb2e0b1664d02a` | 592 | `6e34a51759ad38bd05669b69932a1119ca84cf284203ca3deefb2e0b1664d02a` | 592 | TRUE |
| `common/IOSVersionInfo.m` | `d476ed2ca27e6d08721409a33695d6b42089b221dd778e929fe8c024198409c7` | 15529 | `d476ed2ca27e6d08721409a33695d6b42089b221dd778e929fe8c024198409c7` | 15529 | TRUE |
| `common/IPMonitorService.h` | `202a42c2804fa7d48c40c9ba44cc88bb7a45f584261c5afb51ff2b643a6b3317` | 224 | `202a42c2804fa7d48c40c9ba44cc88bb7a45f584261c5afb51ff2b643a6b3317` | 224 | TRUE |
| `common/IPMonitorService.m` | `ded7e466921b9d4269488e5413ab2990622275259eb5c4954928ff09dcd83110` | 25567 | `ded7e466921b9d4269488e5413ab2990622275259eb5c4954928ff09dcd83110` | 25567 | TRUE |
| `common/IPStatusCacheManager.h` | `494c8e1e4aaeb1a4462fec95e56ed88249d72ea6f79fd5fffc501be83e39c887` | 990 | `494c8e1e4aaeb1a4462fec95e56ed88249d72ea6f79fd5fffc501be83e39c887` | 990 | TRUE |
| `common/IPStatusCacheManager.m` | `0136ffd0b9c62a1f30f5f11543650b45f110bdd3a0eabb5bd084b70bf92acc39` | 12562 | `0136ffd0b9c62a1f30f5f11543650b45f110bdd3a0eabb5bd084b70bf92acc39` | 12562 | TRUE |
| `common/IPStatusViewController.h` | `24d983dca6be3c22410fbf51311a81a7a74027bfdd3e257d4c0b0b2eaa83eb73` | 271 | `24d983dca6be3c22410fbf51311a81a7a74027bfdd3e257d4c0b0b2eaa83eb73` | 271 | TRUE |
| `common/IPStatusViewController.m` | `dd37fc4c0835422d88388dac46c02613eaad7d28cc3f20c3d0c63fb8221faa01` | 62749 | `dd37fc4c0835422d88388dac46c02613eaad7d28cc3f20c3d0c63fb8221faa01` | 62749 | TRUE |
| `common/IPhoneModelDB.h` | `93244605e5ea9088a44447686a27a22a39d132021b74b044212ef00e4633c449` | 885 | `93244605e5ea9088a44447686a27a22a39d132021b74b044212ef00e4633c449` | 885 | TRUE |
| `common/IPhoneModelDB.m` | `e6a75c47d3aa47655cd0546237570b49f511c1d1c991f0fc850e65eae15cfd13` | 6198 | `e6a75c47d3aa47655cd0546237570b49f511c1d1c991f0fc850e65eae15cfd13` | 6198 | TRUE |
| `common/IdentifierManager.h` | `3c2c6c4a8c9ff7a39210229ee7c1d8f59e6bb2f6ac0358ea70fbd9e413f073da` | 3082 | `3c2c6c4a8c9ff7a39210229ee7c1d8f59e6bb2f6ac0358ea70fbd9e413f073da` | 3082 | TRUE |
| `common/IdentifierManager.m` | `f5fc51f24a50ce5457034326de4b5a5e64592d4dd2427b118e75137fe32fe48f` | 160824 | `f5fc51f24a50ce5457034326de4b5a5e64592d4dd2427b118e75137fe32fe48f` | 160824 | TRUE |
| `common/KeychainUUIDManager.h` | `e1354e95536dc3218b3afbc3f198aad582285b0037717ca0fb5515048d8eb626` | 405 | `e1354e95536dc3218b3afbc3f198aad582285b0037717ca0fb5515048d8eb626` | 405 | TRUE |
| `common/KeychainUUIDManager.m` | `954bc45263985727851347397300ea31ff908e0464a5cf4efdf29a93df633e02` | 3479 | `954bc45263985727851347397300ea31ff908e0464a5cf4efdf29a93df633e02` | 3479 | TRUE |
| `common/LocationSpoofingManager.h` | `fcdcc9cbd2ef2edecd9461b0df81376468fd525cf4d2bf361a931d556cb8ffa3` | 3202 | `fcdcc9cbd2ef2edecd9461b0df81376468fd525cf4d2bf361a931d556cb8ffa3` | 3202 | TRUE |
| `common/LocationSpoofingManager.m` | `12d2d700334d36bb49abd5231155c85f49e42db1ea9abfc374750f06d3760581` | 65282 | `12d2d700334d36bb49abd5231155c85f49e42db1ea9abfc374750f06d3760581` | 65282 | TRUE |
| `common/NetworkManager.h` | `2f05d075712b6ab037e94d10fe885a4fb2277cbf97ed8e56ae2831398c37cdea` | 1065 | `2f05d075712b6ab037e94d10fe885a4fb2277cbf97ed8e56ae2831398c37cdea` | 1065 | TRUE |
| `common/NetworkManager.m` | `d991dc30a5a172f0ac5497a95ee8407f7fc4062b96582415abf7b71cacad7af8` | 17926 | `d991dc30a5a172f0ac5497a95ee8407f7fc4062b96582415abf7b71cacad7af8` | 17926 | TRUE |
| `common/PXPaths.h` | `106bdf4dd1a58c34af7edb804515d7751807897834fdd798d99cd4ec2f853f9d` | 616 | `106bdf4dd1a58c34af7edb804515d7751807897834fdd798d99cd4ec2f853f9d` | 616 | TRUE |
| `common/PXPaths.m` | `3577ba31ef5e8c8282657b06b198606b54ccebbdcf30075a2b1ec4703d810de9` | 2283 | `3577ba31ef5e8c8282657b06b198606b54ccebbdcf30075a2b1ec4703d810de9` | 2283 | TRUE |
| `common/PXProcessKiller.h` | `a5c0f8a9f821c5841d68495c911db230dc1225bb79468498df1a0fe9f1a405e2` | 554 | `a5c0f8a9f821c5841d68495c911db230dc1225bb79468498df1a0fe9f1a405e2` | 554 | TRUE |
| `common/PXProcessKiller.m` | `e2a1281cbd11b2a67783136fe68c73d802e96458367a7b3e95f95995bafb72b6` | 4565 | `e2a1281cbd11b2a67783136fe68c73d802e96458367a7b3e95f95995bafb72b6` | 4565 | TRUE |
| `common/PassThroughWindow.h` | `aea14d36dea1c40ccf7d369cf5354f56e43bc99076839ac7e7d5792d71d16d11` | 75 | `aea14d36dea1c40ccf7d369cf5354f56e43bc99076839ac7e7d5792d71d16d11` | 75 | TRUE |
| `common/PassThroughWindow.m` | `c23d77e605a331ae040b236faa01d6819fd28f22e01bbe1532fc2f762f537c9c` | 486 | `c23d77e605a331ae040b236faa01d6819fd28f22e01bbe1532fc2f762f537c9c` | 486 | TRUE |
| `common/PasteboardUUIDManager.h` | `5af2e4a7a7584f794c98e46848848b06caac05ce889d92eb39a9a7aeaa64c5af` | 415 | `5af2e4a7a7584f794c98e46848848b06caac05ce889d92eb39a9a7aeaa64c5af` | 415 | TRUE |
| `common/PasteboardUUIDManager.m` | `9be2bf8148188a4f0c063c0691f9f1a1c8139e7fea26e88539ababcf06718078` | 3466 | `9be2bf8148188a4f0c063c0691f9f1a1c8139e7fea26e88539ababcf06718078` | 3466 | TRUE |
| `common/ProfileIndicatorView.h` | `a4d214bd120b31126f0216cd032b4022fa58152393421e6006d32ee903567f7f` | 174 | `a4d214bd120b31126f0216cd032b4022fa58152393421e6006d32ee903567f7f` | 174 | TRUE |
| `common/ProfileIndicatorView.m` | `278783df004305078ff12a2bb747ce544b57b4be5f8bc410139cb739e854c1e0` | 56659 | `278783df004305078ff12a2bb747ce544b57b4be5f8bc410139cb739e854c1e0` | 56659 | TRUE |
| `common/ProfileManager.h` | `f17f634cae35967d04216783a87b386d537fd038d4ee8945982a527a768581e8` | 2322 | `f17f634cae35967d04216783a87b386d537fd038d4ee8945982a527a768581e8` | 2322 | TRUE |
| `common/ProfileManager.m` | `cb9c6d7beb8bf935cd987f24fb465d90a8a0e61c3905de99ca4a48ba566a4178` | 72206 | `cb9c6d7beb8bf935cd987f24fb465d90a8a0e61c3905de99ca4a48ba566a4178` | 72206 | TRUE |
| `common/ProjectXLogging.h` | `ddcc64ac4ab1dcf7130f3b3068e38ac83cbfa7119ed2696fc9c22ac49925676d` | 460 | `ddcc64ac4ab1dcf7130f3b3068e38ac83cbfa7119ed2696fc9c22ac49925676d` | 460 | TRUE |
| `common/ProjectXLogging.m` | `447ddd5d9cef8a552bd56ba6e2f3589b70e7185ae4168aaf424a69dd85cecdff` | 4712 | `447ddd5d9cef8a552bd56ba6e2f3589b70e7185ae4168aaf424a69dd85cecdff` | 4712 | TRUE |
| `common/ScoreMeterView.h` | `0e9fc5d62252750ce6432032d275c920321b8314eb1aa95d8e036ace220ac1b4` | 200 | `0e9fc5d62252750ce6432032d275c920321b8314eb1aa95d8e036ace220ac1b4` | 200 | TRUE |
| `common/ScoreMeterView.m` | `415d41c0765f93d2f33b50912d746f3efd684b66b625d6d9b9a7f59d9a8272a3` | 2650 | `415d41c0765f93d2f33b50912d746f3efd684b66b625d6d9b9a7f59d9a8272a3` | 2650 | TRUE |
| `common/SerialNumberManager.h` | `e93ad6cbfe58c9edb2d44b5c620f4f03d84b71886de47a2933139f3334f07a49` | 486 | `e93ad6cbfe58c9edb2d44b5c620f4f03d84b71886de47a2933139f3334f07a49` | 486 | TRUE |
| `common/SerialNumberManager.m` | `6bc5049f5a7bda8023f2d1ba743f703c964dba99a49da9969c0484a0fe38389b` | 6005 | `6bc5049f5a7bda8023f2d1ba743f703c964dba99a49da9969c0484a0fe38389b` | 6005 | TRUE |
| `common/StorageManager.h` | `3dac3c91e1340ecd4a03f193a1efc5484da0cfee028b8f0c7eec01146c1c3659` | 3350 | `3dac3c91e1340ecd4a03f193a1efc5484da0cfee028b8f0c7eec01146c1c3659` | 3350 | TRUE |
| `common/StorageManager.m` | `e1c43bdcc633d5d15c3d9680f65ffa234a14158ca462ed66f6a1cb62eb096c8c` | 9610 | `e1c43bdcc633d5d15c3d9680f65ffa234a14158ca462ed66f6a1cb62eb096c8c` | 9610 | TRUE |
| `common/SystemUUIDManager.h` | `f4e4413cb563255a9b4fd9a49ea827662da0a698925e5d5e921849ba52f3f646` | 387 | `f4e4413cb563255a9b4fd9a49ea827662da0a698925e5d5e921849ba52f3f646` | 387 | TRUE |
| `common/SystemUUIDManager.m` | `bcf62bc2190c5236cf9fbbf4a6768f922c4ff2a760fdf6c7c02bb815088aee80` | 3422 | `bcf62bc2190c5236cf9fbbf4a6768f922c4ff2a760fdf6c7c02bb815088aee80` | 3422 | TRUE |
| `common/UIButton+SafeConfiguration.h` | `6591286ab29bfc5cc33ae44cbed0d0afc8b0117e65673c49599d83a945679172` | 984 | `6591286ab29bfc5cc33ae44cbed0d0afc8b0117e65673c49599d83a945679172` | 984 | TRUE |
| `common/UIButton+SafeConfiguration.m` | `0d85824389132f835505bd23dedcfe0730f9477ed79bc4e51e1f0937cf90e755` | 1672 | `0d85824389132f835505bd23dedcfe0730f9477ed79bc4e51e1f0937cf90e755` | 1672 | TRUE |
| `common/UIButtonCompat.h` | `beb3a675c2731563de824d09ca899392c91bb776e6861ae986f497189b41cefe` | 1581 | `beb3a675c2731563de824d09ca899392c91bb776e6861ae986f497189b41cefe` | 1581 | TRUE |
| `common/UIButtonCompat.m` | `3077e591bde05e4a7bf8a126b7e946533ffd0d7f56a6e10175f562c6ab8efd68` | 5833 | `3077e591bde05e4a7bf8a126b7e946533ffd0d7f56a6e10175f562c6ab8efd68` | 5833 | TRUE |
| `common/UptimeManager.h` | `2bc2b60a4d351134bfea13c4d0a9c80d0da2ef01fa0c8b69226a67a5fcdefa60` | 1039 | `2bc2b60a4d351134bfea13c4d0a9c80d0da2ef01fa0c8b69226a67a5fcdefa60` | 1039 | TRUE |
| `common/UptimeManager.m` | `1772f1d6c6a4ac8fe67690744be083f90806fa5a53e3fd327b555cafbd429320` | 18221 | `1772f1d6c6a4ac8fe67690744be083f90806fa5a53e3fd327b555cafbd429320` | 18221 | TRUE |
| `common/UserDefaultsUUIDManager.h` | `3636875e5fbf661308ac2c2ee306a1cc615589f37c9e76dfb9f73a207d603806` | 425 | `3636875e5fbf661308ac2c2ee306a1cc615589f37c9e76dfb9f73a207d603806` | 425 | TRUE |
| `common/UserDefaultsUUIDManager.m` | `be8ebdb9af1980e8c6a2ad79f31610dc44fdfe6d7395682efad1f0bb33e12f48` | 3484 | `be8ebdb9af1980e8c6a2ad79f31610dc44fdfe6d7395682efad1f0bb33e12f48` | 3484 | TRUE |
| `common/VersionCompare.h` | `d839282397f82831f9ea163f40f131744021348508f8b51fcfee588613739094` | 519 | `d839282397f82831f9ea163f40f131744021348508f8b51fcfee588613739094` | 519 | TRUE |
| `common/VersionCompare.m` | `ea72d0f06cbd476ed49c0f13f44bb985f1ca8c2bb3d8d16c82e5c292f8df23a4` | 1936 | `ea72d0f06cbd476ed49c0f13f44bb985f1ca8c2bb3d8d16c82e5c292f8df23a4` | 1936 | TRUE |
| `common/WiFiManager.h` | `dcadd6fea432ad255f5a509253d9f6ebb353ab714dd1adc6e20e327b6015fbdc` | 664 | `dcadd6fea432ad255f5a509253d9f6ebb353ab714dd1adc6e20e327b6015fbdc` | 664 | TRUE |
| `common/WiFiManager.m` | `dfc32e8d70c23b0dd95de81c35697e0e1816d3358b4e77228b85430d2a4b98e3` | 26544 | `dfc32e8d70c23b0dd95de81c35697e0e1816d3358b4e77228b85430d2a4b98e3` | 26544 | TRUE |
| `control` | `fcc89e22298b1a2eefa691d09462d1ae6bb86b805deb43ec71d40bce6e33a4ea` | 469 | `fcc89e22298b1a2eefa691d09462d1ae6bb86b805deb43ec71d40bce6e33a4ea` | 469 | TRUE |
| `data/carrier_db.json` | `003d4bc3cfb44f7af45ba59e65afc9305957f0ba57a7b42db44a114402192e1b` | 17230 | `003d4bc3cfb44f7af45ba59e65afc9305957f0ba57a7b42db44a114402192e1b` | 17230 | TRUE |
| `ent.plist` | `ad383179c6f8a88b875aa34ae8a1fb85496ad002512210272a85cc81145c0164` | 2881 | `ad383179c6f8a88b875aa34ae8a1fb85496ad002512210272a85cc81145c0164` | 2881 | TRUE |
| `iOSVersionManager.h` | `91b56e6517f142f5bff9560bf0ad9c111d6a150bafbe57756b9c05e41878948c` | 404 | `91b56e6517f142f5bff9560bf0ad9c111d6a150bafbe57756b9c05e41878948c` | 404 | TRUE |
| `include/.DS_Store` | `d1b132f85d7cbdb006d39402f5e3ab335ddfcb296b2090c6676887034c73894b` | 6148 | `d1b132f85d7cbdb006d39402f5e3ab335ddfcb296b2090c6676887034c73894b` | 6148 | TRUE |
| `include/HookKit` | `27fc5a751717503f49497e1a9e6b5a08347bb83c55478387f073e96fc8e82737` | 38 | `27fc5a751717503f49497e1a9e6b5a08347bb83c55478387f073e96fc8e82737` | 38 | TRUE |
| `include/ellekit/ellekit.h` | `e3b645ef988671709a238480808415ca7601c63b8dcc947a3619fbdbdc593c13` | 5050 | `e3b645ef988671709a238480808415ca7601c63b8dcc947a3619fbdbdc593c13` | 5050 | TRUE |
| `include/substrate.h` | `d51adfd695c82181b0145db7129dc320ea45a2e1ce19028a0b16fd9b1d3563d7` | 44 | `d51adfd695c82181b0145db7129dc320ea45a2e1ce19028a0b16fd9b1d3563d7` | 44 | TRUE |
| `keychain_base_ent.plist` | `8661cc558cb294239068ce2c24958dc2e717e80998c4f342ad1a9c463fb45496` | 912 | `8661cc558cb294239068ce2c24958dc2e717e80998c4f342ad1a9c463fb45496` | 912 | TRUE |
| `layout/Library/libSandy/projectx_filesystem_access.plist` | `6d8f04e9463c9fa8cf096ba4bf25dd312a0bec29cb605d9a93c48e8f29837a49` | 2557 | `6d8f04e9463c9fa8cf096ba4bf25dd312a0bec29cb605d9a93c48e8f29837a49` | 2557 | TRUE |
| `location.png` | `28129305b1bf9bef807b3473f85fc507f1ee21186168e4513b1c875ec94eb889` | 6132 | `28129305b1bf9bef807b3473f85fc507f1ee21186168e4513b1c875ec94eb889` | 6132 | TRUE |
| `main.m` | `7723b95eef99fdc9b8e949daf135cb03e7c8eaad1c000b4db9361eccbfc0f0da` | 23462 | `7723b95eef99fdc9b8e949daf135cb03e7c8eaad1c000b4db9361eccbfc0f0da` | 23462 | TRUE |
| `postinst` | `a0143e7e9e08efca6dd430098185cc816cfdf7c8bb025d504430a74d4b2917e7` | 6118 | `a0143e7e9e08efca6dd430098185cc816cfdf7c8bb025d504430a74d4b2917e7` | 6118 | TRUE |
| `scripts/audit_native_hooks.sh` | `9216ef3fcab69bb66f50d7d4b70296719d615a778005dd24aa6babf7d8d95a99` | 4225 | `9216ef3fcab69bb66f50d7d4b70296719d615a778005dd24aa6babf7d8d95a99` | 4225 | TRUE |
| `scripts/keychain_backup.sh` | `b3f05517ab230b9f37acfefe4c81568e3f88268c5e110653a50b3d30bd9437ae` | 32096 | `b3f05517ab230b9f37acfefe4c81568e3f88268c5e110653a50b3d30bd9437ae` | 32096 | TRUE |
| `scripts/setup_altlist.sh` | `9921781055e69f08bc6cce043c64f3e59eeabb65fff6e240f4efb12e95aeab7a` | 1567 | `9921781055e69f08bc6cce043c64f3e59eeabb65fff6e240f4efb12e95aeab7a` | 1567 | TRUE |
| `setup_app.sh` | `dbbf9afa6efc1be0ad11b2bf3f61d466f827d58ff9e59bb9872cf1897ae7791e` | 1679 | `dbbf9afa6efc1be0ad11b2bf3f61d466f827d58ff9e59bb9872cf1897ae7791e` | 1679 | TRUE |
| `setup_dependencies.sh` | `12fe51bafa3c13ddc8b53d82c8fc0384be6eee43bc34871bac1722bcdf2a9b4b` | 524 | `12fe51bafa3c13ddc8b53d82c8fc0384be6eee43bc34871bac1722bcdf2a9b4b` | 524 | TRUE |
| `weaponx-debug.sh` | `720dfc3a974712d614c30938a0b40e8fb783eedd96aade3bf6f2fa178ceff024` | 6254 | `720dfc3a974712d614c30938a0b40e8fb783eedd96aade3bf6f2fa178ceff024` | 6254 | TRUE |
## Full authorized production diff
```diff
diff --git a/PXBackupStaleWorkspaceCleanup.m b/PXBackupStaleWorkspaceCleanup.m
index 66d2db1..5131b3e 100644
--- a/PXBackupStaleWorkspaceCleanup.m
+++ b/PXBackupStaleWorkspaceCleanup.m
@@ -57,10 +57,21 @@ typedef struct {
     NSUInteger removedEntries;
     BOOL destructiveMutationOccurred;
     dev_t workspaceDevice;
 } PXBackupStaleWorkspaceCleanupTraversalState;

+typedef enum {
+    PXBackupStaleWorkspaceCleanupDirectoryReadModeStrictRecursiveNames = 1,
+    PXBackupStaleWorkspaceCleanupDirectoryReadModeRawTopLevelReservedClassification = 2,
+} PXBackupStaleWorkspaceCleanupDirectoryReadMode;
+
+typedef enum {
+    PXBackupStaleWorkspaceCleanupRawTopLevelNameNonreserved = 0,
+    PXBackupStaleWorkspaceCleanupRawTopLevelNameExactReserved = 1,
+    PXBackupStaleWorkspaceCleanupRawTopLevelNameMalformedReserved = 2,
+} PXBackupStaleWorkspaceCleanupRawTopLevelNameClassification;
+
 static void PXBackupStaleWorkspaceCleanupSetError(
     NSError **error,
     PXBackupStaleWorkspaceCleanupErrorCode code,
     NSString *field,
     NSString *description) {
@@ -257,10 +268,21 @@ static BOOL PXBackupStaleWorkspaceCleanupRollbackCapturedMismatch(
                    originalName,
                    &restored,
                    AT_SYMLINK_NOFOLLOW) == 0;
 }

+static PXBackupStaleWorkspaceCleanupErrorCode
+PXBackupStaleWorkspaceCleanupPostCaptureErrorCode(
+    BOOL rollbackSucceeded,
+    BOOL priorDestructiveMutation,
+    PXBackupStaleWorkspaceCleanupErrorCode operationSpecificCode) {
+    if (rollbackSucceeded) return operationSpecificCode;
+    return priorDestructiveMutation
+        ? PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete
+        : PXBackupStaleWorkspaceCleanupErrorRollbackFailed;
+}
+
 static BOOL PXBackupStaleWorkspaceCleanupCaptureEntry(
     int parentDescriptor,
     const char *sourceName,
     int retainedDescriptor,
     const struct stat *retainedIdentity,
@@ -347,13 +369,14 @@ static BOOL PXBackupStaleWorkspaceCleanupCaptureEntry(
             PXBackupStaleWorkspaceCleanupRollbackCapturedMismatch(parentDescriptor,
                                                            quarantineName,
                                                            sourceName);
         PXBackupStaleWorkspaceCleanupSetError(
             error,
-            (!rollbackSucceeded && priorDestructiveMutation)
-                ? PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete
-                : PXBackupStaleWorkspaceCleanupErrorEntryChanged,
+            PXBackupStaleWorkspaceCleanupPostCaptureErrorCode(
+                rollbackSucceeded,
+                priorDestructiveMutation,
+                PXBackupStaleWorkspaceCleanupErrorEntryChanged),
             PXBackupStaleWorkspaceCleanupEntryField,
             rollbackSucceeded
                 ? @"A changed cleanup entry was restored without deletion"
                 : @"A changed cleanup entry could not be restored safely");
         return NO;
@@ -364,13 +387,14 @@ static BOOL PXBackupStaleWorkspaceCleanupCaptureEntry(
             PXBackupStaleWorkspaceCleanupRollbackCapturedMismatch(parentDescriptor,
                                                            quarantineName,
                                                            sourceName);
         PXBackupStaleWorkspaceCleanupSetError(
             error,
-            (!rollbackSucceeded && priorDestructiveMutation)
-                ? PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete
-                : PXBackupStaleWorkspaceCleanupErrorLimitExceeded,
+            PXBackupStaleWorkspaceCleanupPostCaptureErrorCode(
+                rollbackSucceeded,
+                priorDestructiveMutation,
+                PXBackupStaleWorkspaceCleanupErrorLimitExceeded),
             PXBackupStaleWorkspaceCleanupEntryField,
             @"The private cleanup quarantine name exceeded fixed limits");
         return NO;
     }
     char *retainedName = malloc(quarantineLength + 1U);
@@ -379,13 +403,14 @@ static BOOL PXBackupStaleWorkspaceCleanupCaptureEntry(
             PXBackupStaleWorkspaceCleanupRollbackCapturedMismatch(parentDescriptor,
                                                            quarantineName,
                                                            sourceName);
         PXBackupStaleWorkspaceCleanupSetError(
             error,
-            (!rollbackSucceeded && priorDestructiveMutation)
-                ? PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete
-                : PXBackupStaleWorkspaceCleanupErrorLimitExceeded,
+            PXBackupStaleWorkspaceCleanupPostCaptureErrorCode(
+                rollbackSucceeded,
+                priorDestructiveMutation,
+                PXBackupStaleWorkspaceCleanupErrorLimitExceeded),
             PXBackupStaleWorkspaceCleanupEntryField,
             @"The private cleanup quarantine name could not be retained");
         return NO;
     }
     memcpy(retainedName, quarantineName, quarantineLength + 1U);
@@ -438,40 +463,120 @@ static BOOL PXBackupStaleWorkspaceCleanupValidateComponentString(NSString *compo
         [component containsString:@"\\"]) return NO;
     if (dataOut) *dataOut = data;
     return YES;
 }

-static BOOL PXBackupStaleWorkspaceCleanupValidateEntryName(const char *name,
-                                                     NSUInteger *lengthOut,
-                                                     NSData **dataOut) {
-    if (lengthOut) *lengthOut = 0;
-    if (dataOut) *dataOut = nil;
+static BOOL PXBackupStaleWorkspaceCleanupReadBoundedRawNameLength(
+    const char *name,
+    NSUInteger *lengthOut,
+    BOOL *exceedsComponentLimitOut) {
+    if (lengthOut) *lengthOut = 0U;
+    if (exceedsComponentLimitOut) *exceedsComponentLimitOut = NO;
     if (!name) return NO;
-    size_t length = 0;
+    size_t length = 0U;
     while (length <= PXBackupStaleWorkspaceCleanupMaximumComponentBytes &&
            name[length] != '\0') {
         length += 1U;
     }
-    if (length == 0 || length > PXBackupStaleWorkspaceCleanupMaximumComponentBytes ||
+    if (length == 0U) return NO;
+    if (length > PXBackupStaleWorkspaceCleanupMaximumComponentBytes) {
+        if (lengthOut) {
+            *lengthOut = PXBackupStaleWorkspaceCleanupMaximumComponentBytes + 1U;
+        }
+        if (exceedsComponentLimitOut) *exceedsComponentLimitOut = YES;
+        return YES;
+    }
+    if (lengthOut) *lengthOut = (NSUInteger)length;
+    return YES;
+}
+
+static BOOL PXBackupStaleWorkspaceCleanupValidateStrictRecursiveEntryName(
+    const char *name,
+    NSUInteger length,
+    NSData **dataOut) {
+    if (dataOut) *dataOut = nil;
+    if (!name || length == 0U ||
+        length > PXBackupStaleWorkspaceCleanupMaximumComponentBytes ||
         (length == 1U && name[0] == '.') ||
         (length == 2U && name[0] == '.' && name[1] == '.')) return NO;
-    for (size_t index = 0; index < length; index++) {
+    for (NSUInteger index = 0U; index < length; index++) {
         unsigned char byte = (unsigned char)name[index];
         if (byte == '/' || byte == '\\' || byte < 0x20 || byte == 0x7f) return NO;
     }
     NSData *data = [NSData dataWithBytes:name length:length];
     NSString *string = [[NSString alloc] initWithData:data
                                               encoding:NSUTF8StringEncoding];
     NSData *roundTrip = [string dataUsingEncoding:NSUTF8StringEncoding
                               allowLossyConversion:NO];
     if (!string || !roundTrip || ![roundTrip isEqualToData:data] ||
         PXBackupStaleWorkspaceCleanupStringContainsControl(string)) return NO;
-    if (lengthOut) *lengthOut = (NSUInteger)length;
     if (dataOut) *dataOut = data;
     return YES;
 }

+static BOOL PXBackupStaleWorkspaceCleanupRawNameHasPrefix(
+    const char *name,
+    NSUInteger length,
+    const char *prefix,
+    size_t prefixLength) {
+    return name && prefix && length >= prefixLength &&
+        memcmp(name, prefix, prefixLength) == 0;
+}
+
+static PXBackupStaleWorkspaceCleanupRawTopLevelNameClassification
+PXBackupStaleWorkspaceCleanupClassifyRawTopLevelName(
+    const char *name,
+    NSUInteger length) {
+    const size_t partialPrefixLength =
+        sizeof(PXBackupStaleWorkspaceCleanupPartialPrefix) - 1U;
+    const size_t quarantinePrefixLength =
+        sizeof(PXBackupStaleWorkspaceCleanupQuarantinePrefix) - 1U;
+    BOOL partialPrefix = PXBackupStaleWorkspaceCleanupRawNameHasPrefix(
+        name,
+        length,
+        PXBackupStaleWorkspaceCleanupPartialPrefix,
+        partialPrefixLength);
+    BOOL quarantinePrefix = PXBackupStaleWorkspaceCleanupRawNameHasPrefix(
+        name,
+        length,
+        PXBackupStaleWorkspaceCleanupQuarantinePrefix,
+        quarantinePrefixLength);
+    if (!partialPrefix && !quarantinePrefix) {
+        return PXBackupStaleWorkspaceCleanupRawTopLevelNameNonreserved;
+    }
+    if (partialPrefix) {
+        if (length != partialPrefixLength + 6U) {
+            return PXBackupStaleWorkspaceCleanupRawTopLevelNameMalformedReserved;
+        }
+        for (NSUInteger index = (NSUInteger)partialPrefixLength;
+             index < length;
+             index++) {
+            unsigned char byte = (unsigned char)name[index];
+            BOOL alphanumeric = (byte >= '0' && byte <= '9') ||
+                (byte >= 'A' && byte <= 'Z') ||
+                (byte >= 'a' && byte <= 'z');
+            if (!alphanumeric) {
+                return PXBackupStaleWorkspaceCleanupRawTopLevelNameMalformedReserved;
+            }
+        }
+        return PXBackupStaleWorkspaceCleanupRawTopLevelNameExactReserved;
+    }
+    if (length != quarantinePrefixLength + 32U) {
+        return PXBackupStaleWorkspaceCleanupRawTopLevelNameMalformedReserved;
+    }
+    for (NSUInteger index = (NSUInteger)quarantinePrefixLength;
+         index < length;
+         index++) {
+        unsigned char byte = (unsigned char)name[index];
+        if (!((byte >= '0' && byte <= '9') ||
+              (byte >= 'a' && byte <= 'f'))) {
+            return PXBackupStaleWorkspaceCleanupRawTopLevelNameMalformedReserved;
+        }
+    }
+    return PXBackupStaleWorkspaceCleanupRawTopLevelNameExactReserved;
+}
+
 static char *PXBackupStaleWorkspaceCleanupCopyCString(NSData *data) {
     if (![data isKindOfClass:[NSData class]] || data.length == 0 ||
         data.length > SIZE_MAX - 1U) return NULL;
     char *bytes = malloc(data.length + 1U);
     if (!bytes) return NULL;
@@ -560,16 +665,20 @@ static BOOL PXBackupStaleWorkspaceCleanupDirectoryBindingValid(

 static BOOL PXBackupStaleWorkspaceCleanupReadDirectory(
     int descriptor,
     PXBackupStaleWorkspaceCleanupTraversalState *state,
     BOOL collectNames,
+    PXBackupStaleWorkspaceCleanupDirectoryReadMode readMode,
     NSArray<NSData *> **namesOut,
     BOOL *emptyOut,
     NSError **error) {
     if (namesOut) *namesOut = nil;
     if (emptyOut) *emptyOut = NO;
-    if (descriptor < 0 || (collectNames && !state)) {
+    BOOL supportedMode =
+        readMode == PXBackupStaleWorkspaceCleanupDirectoryReadModeStrictRecursiveNames ||
+        readMode == PXBackupStaleWorkspaceCleanupDirectoryReadModeRawTopLevelReservedClassification;
+    if (descriptor < 0 || (collectNames && (!state || !supportedMode))) {
         PXBackupStaleWorkspaceCleanupSetError(
             error,
             PXBackupStaleWorkspaceCleanupErrorTraversalFailed,
             PXBackupStaleWorkspaceCleanupEntryField,
             @"The cleanup directory could not be traversed");
@@ -602,42 +711,116 @@ static BOOL PXBackupStaleWorkspaceCleanupReadDirectory(
         struct dirent *entry = readdir(directory);
         if (!entry) {
             if (errno != 0) valid = NO;
             break;
         }
-        if (strcmp(entry->d_name, ".") == 0 ||
-            strcmp(entry->d_name, "..") == 0) continue;
-        empty = NO;
-        if (!collectNames) continue;
-        NSUInteger nameLength = 0;
-        NSData *nameData = nil;
-        if (!PXBackupStaleWorkspaceCleanupValidateEntryName(entry->d_name,
-                                                     &nameLength,
-                                                     &nameData)) {
+        NSUInteger nameLength = 0U;
+        BOOL exceedsComponentLimit = NO;
+        if (!PXBackupStaleWorkspaceCleanupReadBoundedRawNameLength(
+                entry->d_name,
+                &nameLength,
+                &exceedsComponentLimit)) {
             PXBackupStaleWorkspaceCleanupSetError(
                 error,
-                PXBackupStaleWorkspaceCleanupErrorUnsafeReservedEntry,
+                PXBackupStaleWorkspaceCleanupErrorTraversalFailed,
                 PXBackupStaleWorkspaceCleanupEntryField,
-                @"The cleanup tree contains an unsafe entry name");
+                @"The cleanup directory contains an unreadable entry name");
             valid = NO;
             break;
         }
+        if (!exceedsComponentLimit &&
+            ((nameLength == 1U && entry->d_name[0] == '.') ||
+             (nameLength == 2U && entry->d_name[0] == '.' &&
+              entry->d_name[1] == '.'))) {
+            continue;
+        }
+        empty = NO;
+        if (!collectNames) continue;
         if (state->visitedEntries >=
                 PXBackupStaleWorkspaceCleanupMaximumVisitedEntries ||
-            nameLength > ULLONG_MAX - state->accumulatedNameBytes ||
-            state->accumulatedNameBytes + nameLength >
+            (unsigned long long)nameLength >
+                ULLONG_MAX - state->accumulatedNameBytes ||
+            state->accumulatedNameBytes + (unsigned long long)nameLength >
                 PXBackupStaleWorkspaceCleanupMaximumAccumulatedNameBytes) {
             PXBackupStaleWorkspaceCleanupSetError(
                 error,
                 PXBackupStaleWorkspaceCleanupErrorLimitExceeded,
                 PXBackupStaleWorkspaceCleanupEntryField,
                 @"The cleanup tree exceeds fixed traversal limits");
             valid = NO;
             break;
         }
         state->visitedEntries += 1U;
-        state->accumulatedNameBytes += nameLength;
+        state->accumulatedNameBytes += (unsigned long long)nameLength;
+
+        if (readMode ==
+                PXBackupStaleWorkspaceCleanupDirectoryReadModeStrictRecursiveNames) {
+            NSData *nameData = nil;
+            if (exceedsComponentLimit ||
+                !PXBackupStaleWorkspaceCleanupValidateStrictRecursiveEntryName(
+                    entry->d_name,
+                    nameLength,
+                    &nameData)) {
+                PXBackupStaleWorkspaceCleanupSetError(
+                    error,
+                    PXBackupStaleWorkspaceCleanupErrorUnsafeReservedEntry,
+                    PXBackupStaleWorkspaceCleanupEntryField,
+                    @"The cleanup tree contains an unsafe entry name");
+                valid = NO;
+                break;
+            }
+            [names addObject:nameData];
+            continue;
+        }
+
+        PXBackupStaleWorkspaceCleanupRawTopLevelNameClassification classification =
+            PXBackupStaleWorkspaceCleanupClassifyRawTopLevelName(
+                entry->d_name,
+                nameLength);
+        if (classification ==
+                PXBackupStaleWorkspaceCleanupRawTopLevelNameNonreserved) {
+            if (exceedsComponentLimit) {
+                PXBackupStaleWorkspaceCleanupSetError(
+                    error,
+                    PXBackupStaleWorkspaceCleanupErrorLimitExceeded,
+                    PXBackupStaleWorkspaceCleanupEntryField,
+                    @"A top-level cleanup name exceeds fixed limits");
+                valid = NO;
+                break;
+            }
+            continue;
+        }
+        if (classification ==
+                PXBackupStaleWorkspaceCleanupRawTopLevelNameMalformedReserved ||
+            exceedsComponentLimit) {
+            PXBackupStaleWorkspaceCleanupSetError(
+                error,
+                PXBackupStaleWorkspaceCleanupErrorReservedNameInvalid,
+                PXBackupStaleWorkspaceCleanupEntryField,
+                @"A reserved stale-workspace name is malformed");
+            valid = NO;
+            break;
+        }
+        if (names.count >= PXBackupStaleWorkspaceCleanupMaximumTopLevelCandidates) {
+            PXBackupStaleWorkspaceCleanupSetError(
+                error,
+                PXBackupStaleWorkspaceCleanupErrorLimitExceeded,
+                PXBackupStaleWorkspaceCleanupEntryField,
+                @"The stale-workspace candidate limit was exceeded");
+            valid = NO;
+            break;
+        }
+        NSData *nameData = [NSData dataWithBytes:entry->d_name length:nameLength];
+        if (![nameData isKindOfClass:[NSData class]]) {
+            PXBackupStaleWorkspaceCleanupSetError(
+                error,
+                PXBackupStaleWorkspaceCleanupErrorLimitExceeded,
+                PXBackupStaleWorkspaceCleanupEntryField,
+                @"A reserved stale-workspace name could not be retained");
+            valid = NO;
+            break;
+        }
         [names addObject:nameData];
     }
     if (closedir(directory) != 0 && valid) valid = NO;
     if (!valid) {
         if (error && !*error) {
@@ -655,29 +838,48 @@ static BOOL PXBackupStaleWorkspaceCleanupReadDirectory(
 }

 static BOOL PXBackupStaleWorkspaceCleanupDirectoryIsEmpty(int descriptor,
                                                     BOOL *emptyOut,
                                                     NSError **error) {
-    return PXBackupStaleWorkspaceCleanupReadDirectory(descriptor,
-                                               NULL,
-                                               NO,
-                                               NULL,
-                                               emptyOut,
-                                               error);
+    return PXBackupStaleWorkspaceCleanupReadDirectory(
+        descriptor,
+        NULL,
+        NO,
+        PXBackupStaleWorkspaceCleanupDirectoryReadModeStrictRecursiveNames,
+        NULL,
+        emptyOut,
+        error);
+}
+
+static BOOL PXBackupStaleWorkspaceCleanupScanStrictRecursiveEntryNames(
+    int descriptor,
+    PXBackupStaleWorkspaceCleanupTraversalState *state,
+    NSArray<NSData *> **namesOut,
+    NSError **error) {
+    return PXBackupStaleWorkspaceCleanupReadDirectory(
+        descriptor,
+        state,
+        YES,
+        PXBackupStaleWorkspaceCleanupDirectoryReadModeStrictRecursiveNames,
+        namesOut,
+        NULL,
+        error);
 }

-static BOOL PXBackupStaleWorkspaceCleanupScanEntryNames(
+static BOOL PXBackupStaleWorkspaceCleanupScanRawTopLevelReservedNames(
     int descriptor,
     PXBackupStaleWorkspaceCleanupTraversalState *state,
     NSArray<NSData *> **namesOut,
     NSError **error) {
-    return PXBackupStaleWorkspaceCleanupReadDirectory(descriptor,
-                                               state,
-                                               YES,
-                                               namesOut,
-                                               NULL,
-                                               error);
+    return PXBackupStaleWorkspaceCleanupReadDirectory(
+        descriptor,
+        state,
+        YES,
+        PXBackupStaleWorkspaceCleanupDirectoryReadModeRawTopLevelReservedClassification,
+        namesOut,
+        NULL,
+        error);
 }

 static BOOL PXBackupStaleWorkspaceCleanupRemoveDirectoryContents(
     int descriptor,
     const struct stat *directoryIdentity,
@@ -1060,14 +1262,15 @@ static BOOL PXBackupStaleWorkspaceCleanupRemoveDirectoryContents(
             PXBackupStaleWorkspaceCleanupEntryField,
             @"A cleanup directory identity changed during traversal");
         return NO;
     }
     NSArray<NSData *> *names = nil;
-    if (!PXBackupStaleWorkspaceCleanupScanEntryNames(descriptor,
-                                              state,
-                                              &names,
-                                              error)) return NO;
+    if (!PXBackupStaleWorkspaceCleanupScanStrictRecursiveEntryNames(
+            descriptor,
+            state,
+            &names,
+            error)) return NO;
     for (NSData *nameData in names) {
         char *name = PXBackupStaleWorkspaceCleanupCopyCString(nameData);
         if (!name) {
             PXBackupStaleWorkspaceCleanupSetError(
                 error,
@@ -1134,66 +1337,10 @@ typedef struct {
     char *name;
     int descriptor;
     struct stat identity;
 } PXBackupStaleWorkspaceCandidate;

-static BOOL PXBackupStaleWorkspaceCleanupBytesHavePrefix(NSData *data,
-                                                          const char *prefix,
-                                                          size_t prefixLength) {
-    return [data isKindOfClass:[NSData class]] && data.length >= prefixLength &&
-        memcmp(data.bytes, prefix, prefixLength) == 0;
-}
-
-static BOOL PXBackupStaleWorkspaceCleanupExactPartialName(NSData *data) {
-    const size_t prefixLength =
-        sizeof(PXBackupStaleWorkspaceCleanupPartialPrefix) - 1U;
-    if (![data isKindOfClass:[NSData class]] ||
-        data.length != prefixLength + 6U ||
-        !PXBackupStaleWorkspaceCleanupBytesHavePrefix(
-            data,
-            PXBackupStaleWorkspaceCleanupPartialPrefix,
-            prefixLength)) return NO;
-    const unsigned char *bytes = data.bytes;
-    for (NSUInteger index = (NSUInteger)prefixLength; index < data.length; index++) {
-        unsigned char byte = bytes[index];
-        BOOL alphanumeric = (byte >= '0' && byte <= '9') ||
-            (byte >= 'A' && byte <= 'Z') ||
-            (byte >= 'a' && byte <= 'z');
-        if (!alphanumeric) return NO;
-    }
-    return YES;
-}
-
-static BOOL PXBackupStaleWorkspaceCleanupExactQuarantineName(NSData *data) {
-    const size_t prefixLength =
-        sizeof(PXBackupStaleWorkspaceCleanupQuarantinePrefix) - 1U;
-    if (![data isKindOfClass:[NSData class]] ||
-        data.length != prefixLength + 32U ||
-        !PXBackupStaleWorkspaceCleanupBytesHavePrefix(
-            data,
-            PXBackupStaleWorkspaceCleanupQuarantinePrefix,
-            prefixLength)) return NO;
-    const unsigned char *bytes = data.bytes;
-    for (NSUInteger index = (NSUInteger)prefixLength; index < data.length; index++) {
-        unsigned char byte = bytes[index];
-        if (!((byte >= '0' && byte <= '9') ||
-              (byte >= 'a' && byte <= 'f'))) return NO;
-    }
-    return YES;
-}
-
-static BOOL PXBackupStaleWorkspaceCleanupReservedPrefix(NSData *data) {
-    return PXBackupStaleWorkspaceCleanupBytesHavePrefix(
-               data,
-               PXBackupStaleWorkspaceCleanupPartialPrefix,
-               sizeof(PXBackupStaleWorkspaceCleanupPartialPrefix) - 1U) ||
-        PXBackupStaleWorkspaceCleanupBytesHavePrefix(
-               data,
-               PXBackupStaleWorkspaceCleanupQuarantinePrefix,
-               sizeof(PXBackupStaleWorkspaceCleanupQuarantinePrefix) - 1U);
-}
-
 static NSComparisonResult PXBackupStaleWorkspaceCleanupCompareData(NSData *left,
                                                                     NSData *right) {
     NSUInteger common = MIN(left.length, right.length);
     int comparison = common == 0 ? 0 : memcmp(left.bytes, right.bytes, common);
     if (comparison < 0) return NSOrderedAscending;
@@ -1441,27 +1588,25 @@ static NSError *PXBackupStaleWorkspaceCleanupErrorOrMissing(NSError *candidate)
     if (_cleanupCompleted) {
         PXBackupStaleWorkspaceCleanupTraversalState validationState = {0};
         validationState.workspaceDevice = _bundleIdentity.st_dev;
         NSArray<NSData *> *names = nil;
         NSError *scanError = nil;
-        if (!PXBackupStaleWorkspaceCleanupScanEntryNames(
+        if (!PXBackupStaleWorkspaceCleanupScanRawTopLevelReservedNames(
                 _bundleDescriptor,
                 &validationState,
                 &names,
                 &scanError)) {
             if (error) *error = PXBackupStaleWorkspaceCleanupErrorOrMissing(scanError);
             return NO;
         }
-        for (NSData *nameData in names) {
-            if (PXBackupStaleWorkspaceCleanupReservedPrefix(nameData)) {
-                PXBackupStaleWorkspaceCleanupSetError(
-                    error,
-                    PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete,
-                    PXBackupStaleWorkspaceCleanupEntryField,
-                    @"Reserved stale-cleanup evidence remains after cleanup");
-                return NO;
-            }
+        if (names.count > 0U) {
+            PXBackupStaleWorkspaceCleanupSetError(
+                error,
+                PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete,
+                PXBackupStaleWorkspaceCleanupEntryField,
+                @"Reserved stale-cleanup evidence remains after cleanup");
+            return NO;
         }
     }
     if (error) *error = nil;
     return YES;
 }
@@ -1487,11 +1632,11 @@ static NSError *PXBackupStaleWorkspaceCleanupErrorOrMissing(NSError *candidate)

     PXBackupStaleWorkspaceCleanupTraversalState state = {0};
     state.workspaceDevice = _bundleIdentity.st_dev;
     NSArray<NSData *> *allNames = nil;
     NSError *scanError = nil;
-    if (!PXBackupStaleWorkspaceCleanupScanEntryNames(
+    if (!PXBackupStaleWorkspaceCleanupScanRawTopLevelReservedNames(
             _bundleDescriptor,
             &state,
             &allNames,
             &scanError)) {
         _cleanupFailed = YES;
@@ -1521,25 +1666,10 @@ static NSError *PXBackupStaleWorkspaceCleanupErrorOrMissing(NSError *candidate)
     }
     NSUInteger candidateCount = 0U;
     BOOL preflightValid = YES;
     NSError *preflightError = nil;
     for (NSData *nameData in sortedNames) {
-        BOOL exactPartial = PXBackupStaleWorkspaceCleanupExactPartialName(nameData);
-        BOOL exactQuarantine =
-            PXBackupStaleWorkspaceCleanupExactQuarantineName(nameData);
-        BOOL reservedPrefix =
-            PXBackupStaleWorkspaceCleanupReservedPrefix(nameData);
-        if (reservedPrefix && !exactPartial && !exactQuarantine) {
-            PXBackupStaleWorkspaceCleanupSetError(
-                &preflightError,
-                PXBackupStaleWorkspaceCleanupErrorReservedNameInvalid,
-                PXBackupStaleWorkspaceCleanupEntryField,
-                @"A reserved stale-workspace name is malformed");
-            preflightValid = NO;
-            break;
-        }
-        if (!exactPartial && !exactQuarantine) continue;
         if (candidateCount >= PXBackupStaleWorkspaceCleanupMaximumTopLevelCandidates) {
             PXBackupStaleWorkspaceCleanupSetError(
                 &preflightError,
                 PXBackupStaleWorkspaceCleanupErrorLimitExceeded,
                 PXBackupStaleWorkspaceCleanupEntryField,
@@ -1747,29 +1877,27 @@ static NSError *PXBackupStaleWorkspaceCleanupErrorOrMissing(NSError *candidate)

     PXBackupStaleWorkspaceCleanupTraversalState finalState = {0};
     finalState.workspaceDevice = _bundleIdentity.st_dev;
     NSArray<NSData *> *finalNames = nil;
     NSError *finalError = nil;
-    if (!PXBackupStaleWorkspaceCleanupScanEntryNames(
+    if (!PXBackupStaleWorkspaceCleanupScanRawTopLevelReservedNames(
             _bundleDescriptor,
             &finalState,
             &finalNames,
             &finalError)) {
         _cleanupFailed = YES;
         if (error) *error = PXBackupStaleWorkspaceCleanupErrorOrMissing(finalError);
         return NO;
     }
-    for (NSData *nameData in finalNames) {
-        if (PXBackupStaleWorkspaceCleanupReservedPrefix(nameData)) {
-            _cleanupFailed = YES;
-            PXBackupStaleWorkspaceCleanupSetError(
-                error,
-                PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete,
-                PXBackupStaleWorkspaceCleanupEntryField,
-                @"Reserved stale-workspace evidence remains after cleanup");
-            return NO;
-        }
+    if (finalNames.count > 0U) {
+        _cleanupFailed = YES;
+        PXBackupStaleWorkspaceCleanupSetError(
+            error,
+            PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete,
+            PXBackupStaleWorkspaceCleanupEntryField,
+            @"Reserved stale-workspace evidence remains after cleanup");
+        return NO;
     }
     NSError *finalLockError = nil;
     if (![_bundleLock validateOwnershipWithError:&finalLockError] ||
         !PXBackupStaleWorkspaceCleanupPathMatchesDescriptor(
             _canonicalBundleDirectoryPath,
```
## Whitespace, CRLF, and NUL audit
The authorized source and report are audited with `git diff --check`. The source has zero embedded NUL bytes, zero CRLF sequences, and a final newline. The report is generated as UTF-8 LF text, trimmed for trailing spaces, contains no embedded NUL, and ends with the exact required status lines.
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
