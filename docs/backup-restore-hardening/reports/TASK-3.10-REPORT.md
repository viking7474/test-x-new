# TASK-3.10 Report — Harden Backup Discovery and Stale Partial Cleanup
## Baseline and exact scope
- Baseline: `aa01f73b761682f3142c10b03ad5ff792331e68e`.
- Authorized production files: `PXBackupDirectoryDiscovery.h/.m`, `PXBackupStaleWorkspaceCleanup.h/.m`, and `AppDataBackupManager.m`.
- Required report: `docs/backup-restore-hardening/reports/TASK-3.10-REPORT.md`.
- All other production files are protected. Coordinator documents present before this task were not modified, staged, reverted, or committed.
- Host baseline evidence recorded `git status --short --untracked-files=all`, `git rev-parse HEAD`, `git log -8 --oneline`, and `git diff --check`.
## Old discovery inventory
The baseline list method used `NSFileManager`, `fileExistsAtPath:`, `contentsOfDirectoryAtPath:error:`, two manual current/legacy loops, path-based manifest existence tests, and manual component sorting. It excluded only the partial-workspace prefix and accepted any directory containing a path-visible `manifest.plist`; it did not bind root, bundle, candidate, manifest, schema version, physical identity, or v4 final name.
Baseline list-method size: 53 lines. Baseline source inventory: `NSFileManager=2`, `fileExistsAtPath=6`, `contentsOfDirectoryAtPath=2`, loops `2`, manual sort `1`.
## Read-only discovery API and sixteen errors
`PXBackupDirectoryDiscovery` is subclassing-restricted, has no public instance state, disables `init/new`, exports exactly two constants and sixteen contiguous error codes, and exposes exactly one class method. Inputs are exact, lossless UTF-8 values with bounds 8 roots, 4096 root bytes, and 255 bundle-component bytes. No trim, normalization, lowercasing, percent decoding, or repair occurs.
## Root and bundle authority
Roots are processed in caller order. Missing roots and bundle directories continue. Existing symlink, wrong-type, setid, cross-filesystem, open, CLOEXEC, or namespace/descriptor failures are systemic. Root and bundle descriptors are retained through each scan and lexical namespace, descriptor identity, type, mode, size, mtime, and ctime are revalidated before accepted paths survive. Physical bundle aliases are scanned once with first-root precedence. No directory is created.
## Reserved exclusions and candidate proof
The lock file, partial prefix, cleanup-quarantine prefix, and every other dot-prefixed name are excluded before candidate inspection. Candidates must be safe exact UTF-8 components, ordinary no-follow directories, non-setid, same-filesystem, CLOEXEC, and exact namespace/descriptor identities. Files, symlinks, special objects, and changed candidates are skipped.
## Bounded manifest read and stability
`manifest.plist` is opened descriptor-relatively with `O_RDONLY|O_NONBLOCK|O_NOFOLLOW|O_CLOEXEC`. It must be regular, nlink 1, non-setid, same-filesystem, namespace/fd-identical, stable, and 1..128 MiB. The reader uses a 64 KiB buffer, retries only `EINTR`, rejects early EOF and extra bytes, and rechecks exact metadata. It parses an immutable property list dictionary and invokes `PXBackupManifestValidator` exactly once per parsed candidate. Discovery source contains no namespace/content mutation API, process execution, `NSFileManager`, or dispatch.
## Versions, v4 binding, v2/v3 compatibility
Only exact integral versions 2, 3, and 4 survive discovery. Unknown positive versions are skipped even when the generic validator accepts their graph. Every version requires exact requested bundle identity. V4 additionally requires directory mode 0700, manifest mode 0600, `atomic-directory-v1`, `complete`, strict UTC `yyyyMMdd-HHmmss`, canonical lowercase UUID, and exact `<timestamp>-<backupID>` directory naming. V2/v3 retain safe nonhidden validated legacy names and do not inherit v4 modes/publication requirements.
## Deduplication and sorting
Before acceptance, candidate and manifest identities are revalidated and the exact root/bundle/name output path is reconstructed. Physical directories are deduplicated by device/inode with first-root precedence. Distinct physical directories with equal basenames remain valid. Results sort newest-first by last path component with full path as deterministic tie-breaker. Accepted output is capped at 4096.
## Stale cleanup API and eighteen errors
`PXBackupStaleWorkspaceCleanup` is subclassing-restricted, exports two constants and eighteen contiguous errors, exposes four readonly properties, one factory, one execution method, and one identity method, and disables `init/new`. It exposes no descriptor, arbitrary path deletion, age threshold, legacy-root mutation, or published-directory deletion API. Code 18 provides a public failure fallback if an internal helper ever returns `NO` without an NSError.
## Lock-not-age stale authority and exact grammar
Staleness derives only from exact ownership of the per-bundle lock, exact canonical bundle binding, execution before current workspace creation, exact direct-child grammar, and exact safe directory proof. No wall clock, mtime, ctime, PID, boot time, or age threshold participates. Accepted top-level names are exactly `.weaponx-backup-partial-` plus six ASCII alphanumeric bytes or `.weaponx-cleanup-quarantine-` plus 32 lowercase hex bytes. Malformed reserved prefixes fail closed before mutation. Published and legacy directories are never targets.
## Deterministic preflight and bounded recursive cleanup
The cleaner validates lock/bundle identity, scans all direct children through one reusable `F_DUPFD_CLOEXEC`/`fdopendir`/`readdir` implementation, classifies all entries, rejects malformed reserved evidence, proves every exact candidate as mode-0700 ordinary directory, retains candidate descriptors, and sorts raw names before mutation. Bounds are 256 top-level candidates, depth 64, 16384 aggregate entries, 255 component bytes, and 8 MiB accumulated names. Within a proven stale tree it removes only single-link non-setid regular files and ordinary non-setid directories; symlink, FIFO, socket, device, cross-filesystem, hardlink, setid, invalid name, or changed identity stops cleanup and preserves evidence. Nested pre-existing quarantine names are ordinary proven entries for crash recovery.
## Atomic quarantine capture, rollback, and durability
One file-local helper contains the sole stale-cleaner `renameatx_np(..., RENAME_EXCL)` site. It clears errno output, validates descriptors/names, retries only EINTR, and has no fallback. Fresh quarantine names use exactly 16 `arc4random_buf` bytes, 32 lowercase hex characters, and at most 16 collision attempts. Every regular file, directory, and top-level stale root is captured before destructive unlink/rmdir. A replacement capture is detected against the retained descriptor and rolled back no-replace after strict parent sync; collision or unprovable rollback preserves evidence. Counters update only after absence/link proofs and strict parent fsync. Top-level cleanup revalidates lock, bundle, root emptiness and mode, captures to fresh quarantine, removes it, proves original/quarantine absence, syncs the bundle directory, then increments both counters. Exact quarantine left by a process crash is recognized on the next run.
## Manager integration
The manager imports each new header once. After lock factory and the existing initial lock validation—but before tar lookup, source resolution, timestamp, backup UUID, workspace factory, output/debug work, process kill, and producers—it creates one precise-lifetime stale cleaner, validates it, executes once, and validates again. Any failure returns nil result with the exact stale error on the main queue and does not create a current workspace or invoke live TASK-3.9 cleanup. Lock validation count remains four. The list method reads `_backupRoot` once, constructs current-first and lexically distinct legacy roots, calls discovery once, and maps systemic failure to `@[]` because the public selector has no error channel. `readManifestAtBackupDirectory:error:` and Restore are byte-identical.
## Static gates
| Gate | Result |
|---|---:|
| Discovery exports / errors / class methods / properties | 2 / 16 / 1 / 0 |
| Discovery F_DUPFD_CLOEXEC / fdopendir / readdir | 1 / 1 / 1 |
| Discovery validator call sites | 1 |
| Discovery mutation APIs / NSFileManager / dispatch | 0 / 0 / 0 |
| Stale exports / errors / readonly properties | 2 / 18 / 4 |
| Stale fdopendir / readdir | 1 / 1 |
| Stale arc4random_buf / renameatx_np / RENAME_EXCL | 1 / 1 / 1 |
| Stale plain renameat / dlsym / syscall / fallback | 0 / 0 / 0 / 0 |
| Original-name destructive unlink/rmdir | 0 |
| Manager discovery calls / _backupRoot reads | 1 / 1 |
| Manager stale factory / validations / execution | 1 / 2 / 1 |
| Lock/workspace/artifact/manifest/publisher validations | 4 / 3 / 3 / 3 / 3 |
| Artifact writes / manifest writes / publisher publish | 8 / 1 / 1 |
| Policy constructions / failure-policy / audit | 8 / 8 / 1 |
| V4 builder / manager validator | 1 / 1 |
| Failure funnel / live cleanup / disarm | 33 / 1 / 1 |
| Publisher renameatx_np / live cleanup renameatx_np / stale renameatx_np | 1 / 1 / 1 |
| Protected workspace files changed | 0 |
## Validation and build status
- Discovery strict Objective-C frontend/analyzer: portable PASS; `__APPLE__` stat branch PASS.
- Stale-cleaner strict Objective-C frontend/analyzer: portable PASS; `__APPLE__` stat branch PASS.
- Manager list/stale integration harness: assertions-enabled PASS; `NS_BLOCK_ASSERTIONS` PASS.
- Malformed public-call harness with `@try/@catch`: PASS at strict frontend.
- Executable deterministic semantic model: 4,345 cases PASS, covering discovery input/version/mode/name/read/dedup/sort behavior, stale grammar/preflight/bounds/quarantine/rollback/counter ordering, and manager failure ordering.
- Full Theos/Apple SDK arm64/arm64e link and target APFS concurrent mutation/crash replay are unavailable in this Windows workspace and remain authoritative GitHub Actions/device gates. Local declaration stubs are not claimed as an Apple SDK build. Remaining runtime risk is platform-specific filesystem behavior under true concurrent rename/unlink/crash faults; all paths fail closed and preserve unproven evidence.
## Explicit scenario matrix
Explicit scenarios: 285.

| # | Category | Input/state | Expected proof |
|---:|---|---|---|
| 1 | discovery-input | roots array count = 0 | accept only counts 1 through 8; otherwise InvalidInput |
| 2 | discovery-input | roots array count = 1 | accept only counts 1 through 8; otherwise InvalidInput |
| 3 | discovery-input | roots array count = 2 | accept only counts 1 through 8; otherwise InvalidInput |
| 4 | discovery-input | roots array count = 3 | accept only counts 1 through 8; otherwise InvalidInput |
| 5 | discovery-input | roots array count = 4 | accept only counts 1 through 8; otherwise InvalidInput |
| 6 | discovery-input | roots array count = 5 | accept only counts 1 through 8; otherwise InvalidInput |
| 7 | discovery-input | roots array count = 6 | accept only counts 1 through 8; otherwise InvalidInput |
| 8 | discovery-input | roots array count = 7 | accept only counts 1 through 8; otherwise InvalidInput |
| 9 | discovery-input | roots array count = 8 | accept only counts 1 through 8; otherwise InvalidInput |
| 10 | discovery-input | roots array count = 9 | accept only counts 1 through 8; otherwise InvalidInput |
| 11 | discovery-input | roots array count = 10 | accept only counts 1 through 8; otherwise InvalidInput |
| 12 | discovery-input | nil | fail closed with discovery NSError except valid absolute bounded root |
| 13 | discovery-input | NSDictionary | fail closed with discovery NSError except valid absolute bounded root |
| 14 | discovery-input | NSArray nested wrong type | fail closed with discovery NSError except valid absolute bounded root |
| 15 | discovery-input | empty string | fail closed with discovery NSError except valid absolute bounded root |
| 16 | discovery-input | relative root | fail closed with discovery NSError except valid absolute bounded root |
| 17 | discovery-input | absolute root | fail closed with discovery NSError except valid absolute bounded root |
| 18 | discovery-input | root with embedded NUL | fail closed with discovery NSError except valid absolute bounded root |
| 19 | discovery-input | root 4096 UTF-8 bytes | fail closed with discovery NSError except valid absolute bounded root |
| 20 | discovery-input | root 4097 UTF-8 bytes | fail closed with discovery NSError except valid absolute bounded root |
| 21 | discovery-input | lossy UTF-8 root | fail closed with discovery NSError except valid absolute bounded root |
| 22 | root-authority | missing root | missing continues; unsafe/systemic states fail; exact directory remains read-only |
| 23 | root-authority | regular-file root | missing continues; unsafe/systemic states fail; exact directory remains read-only |
| 24 | root-authority | symlink root | missing continues; unsafe/systemic states fail; exact directory remains read-only |
| 25 | root-authority | FIFO root | missing continues; unsafe/systemic states fail; exact directory remains read-only |
| 26 | root-authority | setuid root | missing continues; unsafe/systemic states fail; exact directory remains read-only |
| 27 | root-authority | setgid root | missing continues; unsafe/systemic states fail; exact directory remains read-only |
| 28 | root-authority | valid directory root | missing continues; unsafe/systemic states fail; exact directory remains read-only |
| 29 | root-authority | root replaced before open | missing continues; unsafe/systemic states fail; exact directory remains read-only |
| 30 | root-authority | root replaced during scan | missing continues; unsafe/systemic states fail; exact directory remains read-only |
| 31 | root-authority | root descriptor without CLOEXEC | missing continues; unsafe/systemic states fail; exact directory remains read-only |
| 32 | root-authority | root lstat EACCES | missing continues; unsafe/systemic states fail; exact directory remains read-only |
| 33 | root-authority | root open ELOOP | missing continues; unsafe/systemic states fail; exact directory remains read-only |
| 34 | bundle-authority | missing bundle directory | missing continues; unsafe states fail; physical alias scanned once with first-root precedence |
| 35 | bundle-authority | bundle symlink | missing continues; unsafe states fail; physical alias scanned once with first-root precedence |
| 36 | bundle-authority | bundle file | missing continues; unsafe states fail; physical alias scanned once with first-root precedence |
| 37 | bundle-authority | bundle special object | missing continues; unsafe states fail; physical alias scanned once with first-root precedence |
| 38 | bundle-authority | bundle setid | missing continues; unsafe states fail; physical alias scanned once with first-root precedence |
| 39 | bundle-authority | bundle cross-filesystem | missing continues; unsafe states fail; physical alias scanned once with first-root precedence |
| 40 | bundle-authority | bundle changed before open | missing continues; unsafe states fail; physical alias scanned once with first-root precedence |
| 41 | bundle-authority | bundle changed during scan | missing continues; unsafe states fail; physical alias scanned once with first-root precedence |
| 42 | bundle-authority | bundle valid directory | missing continues; unsafe states fail; physical alias scanned once with first-root precedence |
| 43 | bundle-authority | current/legacy physical alias | missing continues; unsafe states fail; physical alias scanned once with first-root precedence |
| 44 | reserved-exclusion | .weaponx-backup.lock | all dot/reserved names excluded; visible safe components remain candidates |
| 45 | reserved-exclusion | .weaponx-backup-partial-ABC123 | all dot/reserved names excluded; visible safe components remain candidates |
| 46 | reserved-exclusion | .weaponx-cleanup-quarantine-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa | all dot/reserved names excluded; visible safe components remain candidates |
| 47 | reserved-exclusion | .hidden | all dot/reserved names excluded; visible safe components remain candidates |
| 48 | reserved-exclusion | . | all dot/reserved names excluded; visible safe components remain candidates |
| 49 | reserved-exclusion | .. | all dot/reserved names excluded; visible safe components remain candidates |
| 50 | reserved-exclusion | .other | all dot/reserved names excluded; visible safe components remain candidates |
| 51 | reserved-exclusion | 20260715-120000-id | all dot/reserved names excluded; visible safe components remain candidates |
| 52 | reserved-exclusion | legacy-name | all dot/reserved names excluded; visible safe components remain candidates |
| 53 | reserved-exclusion | visible | all dot/reserved names excluded; visible safe components remain candidates |
| 54 | candidate-proof | regular file candidate | skip unsafe/changed; accept validated physical directory once |
| 55 | candidate-proof | symlink candidate | skip unsafe/changed; accept validated physical directory once |
| 56 | candidate-proof | FIFO candidate | skip unsafe/changed; accept validated physical directory once |
| 57 | candidate-proof | socket candidate | skip unsafe/changed; accept validated physical directory once |
| 58 | candidate-proof | device candidate | skip unsafe/changed; accept validated physical directory once |
| 59 | candidate-proof | cross-filesystem directory | skip unsafe/changed; accept validated physical directory once |
| 60 | candidate-proof | setid directory | skip unsafe/changed; accept validated physical directory once |
| 61 | candidate-proof | changed directory | skip unsafe/changed; accept validated physical directory once |
| 62 | candidate-proof | valid directory 0700 | skip unsafe/changed; accept validated physical directory once |
| 63 | candidate-proof | valid legacy directory 0755 | skip unsafe/changed; accept validated physical directory once |
| 64 | candidate-proof | duplicate physical directory | skip unsafe/changed; accept validated physical directory once |
| 65 | candidate-proof | same basename distinct inode | skip unsafe/changed; accept validated physical directory once |
| 66 | manifest-size | 0 | accept only 1 through 128 MiB, using 64 KiB bounded reads |
| 67 | manifest-size | 1 | accept only 1 through 128 MiB, using 64 KiB bounded reads |
| 68 | manifest-size | 65535 | accept only 1 through 128 MiB, using 64 KiB bounded reads |
| 69 | manifest-size | 65536 | accept only 1 through 128 MiB, using 64 KiB bounded reads |
| 70 | manifest-size | 65537 | accept only 1 through 128 MiB, using 64 KiB bounded reads |
| 71 | manifest-size | 134217728 | accept only 1 through 128 MiB, using 64 KiB bounded reads |
| 72 | manifest-size | 134217729 | accept only 1 through 128 MiB, using 64 KiB bounded reads |
| 73 | manifest-proof | missing manifest | skip candidate unless regular nlink1 stable exact bounded read succeeds |
| 74 | manifest-proof | manifest symlink | skip candidate unless regular nlink1 stable exact bounded read succeeds |
| 75 | manifest-proof | manifest directory | skip candidate unless regular nlink1 stable exact bounded read succeeds |
| 76 | manifest-proof | manifest FIFO | skip candidate unless regular nlink1 stable exact bounded read succeeds |
| 77 | manifest-proof | manifest hardlink | skip candidate unless regular nlink1 stable exact bounded read succeeds |
| 78 | manifest-proof | manifest setid | skip candidate unless regular nlink1 stable exact bounded read succeeds |
| 79 | manifest-proof | manifest cross-filesystem | skip candidate unless regular nlink1 stable exact bounded read succeeds |
| 80 | manifest-proof | manifest descriptor mismatch | skip candidate unless regular nlink1 stable exact bounded read succeeds |
| 81 | manifest-proof | early EOF | skip candidate unless regular nlink1 stable exact bounded read succeeds |
| 82 | manifest-proof | extra byte | skip candidate unless regular nlink1 stable exact bounded read succeeds |
| 83 | manifest-proof | size mutation | skip candidate unless regular nlink1 stable exact bounded read succeeds |
| 84 | manifest-proof | mode mutation | skip candidate unless regular nlink1 stable exact bounded read succeeds |
| 85 | manifest-proof | mtime mutation | skip candidate unless regular nlink1 stable exact bounded read succeeds |
| 86 | manifest-proof | ctime mutation | skip candidate unless regular nlink1 stable exact bounded read succeeds |
| 87 | manifest-proof | inode mutation | skip candidate unless regular nlink1 stable exact bounded read succeeds |
| 88 | manifest-proof | exact stable manifest | skip candidate unless regular nlink1 stable exact bounded read succeeds |
| 89 | manifest-version | 1 | accept exact integral versions 2/3/4 only after one validator call |
| 90 | manifest-version | 2 | accept exact integral versions 2/3/4 only after one validator call |
| 91 | manifest-version | 3 | accept exact integral versions 2/3/4 only after one validator call |
| 92 | manifest-version | 4 | accept exact integral versions 2/3/4 only after one validator call |
| 93 | manifest-version | 5 | accept exact integral versions 2/3/4 only after one validator call |
| 94 | manifest-version | 100 | accept exact integral versions 2/3/4 only after one validator call |
| 95 | manifest-version | negative | accept exact integral versions 2/3/4 only after one validator call |
| 96 | manifest-version | Boolean true | accept exact integral versions 2/3/4 only after one validator call |
| 97 | manifest-version | floating 4.0 | accept exact integral versions 2/3/4 only after one validator call |
| 98 | manifest-version | string 4 | accept exact integral versions 2/3/4 only after one validator call |
| 99 | manifest-schema | plist parse failure | skip malformed candidate; exact validated dictionary/bundle identity required |
| 100 | manifest-schema | plist array root | skip malformed candidate; exact validated dictionary/bundle identity required |
| 101 | manifest-schema | plist dictionary root | skip malformed candidate; exact validated dictionary/bundle identity required |
| 102 | manifest-schema | validator NO | skip malformed candidate; exact validated dictionary/bundle identity required |
| 103 | manifest-schema | validator exception | skip malformed candidate; exact validated dictionary/bundle identity required |
| 104 | manifest-schema | wrong bundleID type | skip malformed candidate; exact validated dictionary/bundle identity required |
| 105 | manifest-schema | wrong bundleID value | skip malformed candidate; exact validated dictionary/bundle identity required |
| 106 | manifest-schema | exact bundleID | skip malformed candidate; exact validated dictionary/bundle identity required |
| 107 | v4-binding | directory mode 0700 | v4 accepted only with exact modes/protocol/state/canonical timestamp UUID and exact final name |
| 108 | v4-binding | directory mode 0755 | v4 accepted only with exact modes/protocol/state/canonical timestamp UUID and exact final name |
| 109 | v4-binding | manifest mode 0600 | v4 accepted only with exact modes/protocol/state/canonical timestamp UUID and exact final name |
| 110 | v4-binding | manifest mode 0644 | v4 accepted only with exact modes/protocol/state/canonical timestamp UUID and exact final name |
| 111 | v4-binding | protocol atomic-directory-v1 | v4 accepted only with exact modes/protocol/state/canonical timestamp UUID and exact final name |
| 112 | v4-binding | protocol legacy | v4 accepted only with exact modes/protocol/state/canonical timestamp UUID and exact final name |
| 113 | v4-binding | contentState complete | v4 accepted only with exact modes/protocol/state/canonical timestamp UUID and exact final name |
| 114 | v4-binding | contentState partial | v4 accepted only with exact modes/protocol/state/canonical timestamp UUID and exact final name |
| 115 | v4-binding | timestamp exact UTC | v4 accepted only with exact modes/protocol/state/canonical timestamp UUID and exact final name |
| 116 | v4-binding | timestamp invalid date | v4 accepted only with exact modes/protocol/state/canonical timestamp UUID and exact final name |
| 117 | v4-binding | timestamp wrong length | v4 accepted only with exact modes/protocol/state/canonical timestamp UUID and exact final name |
| 118 | v4-binding | UUID lowercase canonical | v4 accepted only with exact modes/protocol/state/canonical timestamp UUID and exact final name |
| 119 | v4-binding | UUID uppercase | v4 accepted only with exact modes/protocol/state/canonical timestamp UUID and exact final name |
| 120 | v4-binding | UUID missing hyphens | v4 accepted only with exact modes/protocol/state/canonical timestamp UUID and exact final name |
| 121 | v4-binding | name exact timestamp-UUID | v4 accepted only with exact modes/protocol/state/canonical timestamp UUID and exact final name |
| 122 | v4-binding | name repaired alternate | v4 accepted only with exact modes/protocol/state/canonical timestamp UUID and exact final name |
| 123 | v4-binding | name timestamp only | v4 accepted only with exact modes/protocol/state/canonical timestamp UUID and exact final name |
| 124 | legacy-compatibility | v2 timestamp directory | retain validated v2/v3 behavior without UUID suffix or v4 mode/publication requirements |
| 125 | legacy-compatibility | v2 arbitrary safe legacy name | retain validated v2/v3 behavior without UUID suffix or v4 mode/publication requirements |
| 126 | legacy-compatibility | v2 mode 0755 | retain validated v2/v3 behavior without UUID suffix or v4 mode/publication requirements |
| 127 | legacy-compatibility | v3 timestamp directory | retain validated v2/v3 behavior without UUID suffix or v4 mode/publication requirements |
| 128 | legacy-compatibility | v3 arbitrary safe legacy name | retain validated v2/v3 behavior without UUID suffix or v4 mode/publication requirements |
| 129 | legacy-compatibility | v3 mode 0755 | retain validated v2/v3 behavior without UUID suffix or v4 mode/publication requirements |
| 130 | dedup-sort | same bundle inode through current then legacy | dedupe physical identity, first-root precedence, newest component first, deterministic full-path tie break, enforce 4096 cap |
| 131 | dedup-sort | same candidate inode under two roots | dedupe physical identity, first-root precedence, newest component first, deterministic full-path tie break, enforce 4096 cap |
| 132 | dedup-sort | two distinct inodes same basename | dedupe physical identity, first-root precedence, newest component first, deterministic full-path tie break, enforce 4096 cap |
| 133 | dedup-sort | three different timestamps | dedupe physical identity, first-root precedence, newest component first, deterministic full-path tie break, enforce 4096 cap |
| 134 | dedup-sort | same component different full path | dedupe physical identity, first-root precedence, newest component first, deterministic full-path tie break, enforce 4096 cap |
| 135 | dedup-sort | zero accepted | dedupe physical identity, first-root precedence, newest component first, deterministic full-path tie break, enforce 4096 cap |
| 136 | dedup-sort | 4096 accepted | dedupe physical identity, first-root precedence, newest component first, deterministic full-path tie break, enforce 4096 cap |
| 137 | dedup-sort | 4097 accepted | dedupe physical identity, first-root precedence, newest component first, deterministic full-path tie break, enforce 4096 cap |
| 138 | stale-grammar | .weaponx-backup-partial-ABC123 | exact stale partial candidate |
| 139 | stale-grammar | .weaponx-backup-partial-abcdef | exact stale partial candidate |
| 140 | stale-grammar | .weaponx-backup-partial-000000 | exact stale partial candidate |
| 141 | stale-grammar | .weaponx-backup-partial-Z9z9Z9 | exact stale partial candidate |
| 142 | stale-grammar | .weaponx-backup-partial- | malformed reserved prefix fails preflight before mutation |
| 143 | stale-grammar | .weaponx-backup-partial-ABCDE | malformed reserved prefix fails preflight before mutation |
| 144 | stale-grammar | .weaponx-backup-partial-ABCDEFG | malformed reserved prefix fails preflight before mutation |
| 145 | stale-grammar | .weaponx-backup-partial-abc-12 | malformed reserved prefix fails preflight before mutation |
| 146 | stale-grammar | .weaponx-backup-partial-abc_12 | malformed reserved prefix fails preflight before mutation |
| 147 | stale-grammar | .weaponx-backup-partial-ábc123 | malformed reserved prefix fails preflight before mutation |
| 148 | stale-grammar | .weaponx-backup-partial-abc12! | malformed reserved prefix fails preflight before mutation |
| 149 | stale-grammar | .weaponx-cleanup-quarantine-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa | exact prior cleanup quarantine candidate |
| 150 | stale-grammar | .weaponx-cleanup-quarantine-00000000000000000000000000000000 | exact prior cleanup quarantine candidate |
| 151 | stale-grammar | .weaponx-cleanup-quarantine-0123456789abcdef0123456789abcdef | exact prior cleanup quarantine candidate |
| 152 | stale-grammar | .weaponx-cleanup-quarantine- | malformed reserved prefix fails preflight before mutation |
| 153 | stale-grammar | .weaponx-cleanup-quarantine-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa | malformed reserved prefix fails preflight before mutation |
| 154 | stale-grammar | .weaponx-cleanup-quarantine-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa | malformed reserved prefix fails preflight before mutation |
| 155 | stale-grammar | .weaponx-cleanup-quarantine-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA | malformed reserved prefix fails preflight before mutation |
| 156 | stale-grammar | .weaponx-cleanup-quarantine-gggggggggggggggggggggggggggggggg | malformed reserved prefix fails preflight before mutation |
| 157 | stale-grammar | .weaponx-cleanup-quarantine-0000000000000000000000000000000- | malformed reserved prefix fails preflight before mutation |
| 158 | stale-nontarget | .weaponx-backup.lock | never selected as stale cleanup target |
| 159 | stale-nontarget | published-timestamp-uuid | never selected as stale cleanup target |
| 160 | stale-nontarget | legacy-published | never selected as stale cleanup target |
| 161 | stale-nontarget | nonreserved-hidden | never selected as stale cleanup target |
| 162 | stale-nontarget | .cache | never selected as stale cleanup target |
| 163 | stale-nontarget | ordinary-file | never selected as stale cleanup target |
| 164 | stale-nontarget | ordinary-directory | never selected as stale cleanup target |
| 165 | stale-preflight | candidate file | classify/prove every exact reserved candidate before first mutation; unsafe/limit failure preserves all |
| 166 | stale-preflight | candidate symlink | classify/prove every exact reserved candidate before first mutation; unsafe/limit failure preserves all |
| 167 | stale-preflight | candidate FIFO | classify/prove every exact reserved candidate before first mutation; unsafe/limit failure preserves all |
| 168 | stale-preflight | candidate socket | classify/prove every exact reserved candidate before first mutation; unsafe/limit failure preserves all |
| 169 | stale-preflight | candidate device | classify/prove every exact reserved candidate before first mutation; unsafe/limit failure preserves all |
| 170 | stale-preflight | candidate cross-filesystem | classify/prove every exact reserved candidate before first mutation; unsafe/limit failure preserves all |
| 171 | stale-preflight | candidate hard-linked evidence | classify/prove every exact reserved candidate before first mutation; unsafe/limit failure preserves all |
| 172 | stale-preflight | candidate setid | classify/prove every exact reserved candidate before first mutation; unsafe/limit failure preserves all |
| 173 | stale-preflight | candidate mode 0755 | classify/prove every exact reserved candidate before first mutation; unsafe/limit failure preserves all |
| 174 | stale-preflight | candidate identity change | classify/prove every exact reserved candidate before first mutation; unsafe/limit failure preserves all |
| 175 | stale-preflight | all candidates exact | classify/prove every exact reserved candidate before first mutation; unsafe/limit failure preserves all |
| 176 | stale-preflight | 257 exact candidates | classify/prove every exact reserved candidate before first mutation; unsafe/limit failure preserves all |
| 177 | stale-limits | depth: 64 allowed | enforce fixed overflow-safe bound before unsafe mutation |
| 178 | stale-limits | depth: 65 rejected | enforce fixed overflow-safe bound before unsafe mutation |
| 179 | stale-limits | entries: 16384 allowed | enforce fixed overflow-safe bound before unsafe mutation |
| 180 | stale-limits | entries: 16385 rejected | enforce fixed overflow-safe bound before unsafe mutation |
| 181 | stale-limits | component: 255 bytes allowed | enforce fixed overflow-safe bound before unsafe mutation |
| 182 | stale-limits | component: 256 bytes rejected | enforce fixed overflow-safe bound before unsafe mutation |
| 183 | stale-limits | names: 8 MiB bounded | enforce fixed overflow-safe bound before unsafe mutation |
| 184 | stale-limits | top-level: 256 allowed | enforce fixed overflow-safe bound before unsafe mutation |
| 185 | stale-limits | top-level: 257 rejected | enforce fixed overflow-safe bound before unsafe mutation |
| 186 | recursive-cleanup | single-link regular file | remove only exact proven regular files/directories; nested quarantine ordinary; unsafe evidence preserved |
| 187 | recursive-cleanup | hard-linked file | remove only exact proven regular files/directories; nested quarantine ordinary; unsafe evidence preserved |
| 188 | recursive-cleanup | setid file | remove only exact proven regular files/directories; nested quarantine ordinary; unsafe evidence preserved |
| 189 | recursive-cleanup | file identity replacement | remove only exact proven regular files/directories; nested quarantine ordinary; unsafe evidence preserved |
| 190 | recursive-cleanup | ordinary directory | remove only exact proven regular files/directories; nested quarantine ordinary; unsafe evidence preserved |
| 191 | recursive-cleanup | directory setid | remove only exact proven regular files/directories; nested quarantine ordinary; unsafe evidence preserved |
| 192 | recursive-cleanup | directory cross-filesystem | remove only exact proven regular files/directories; nested quarantine ordinary; unsafe evidence preserved |
| 193 | recursive-cleanup | directory repopulated | remove only exact proven regular files/directories; nested quarantine ordinary; unsafe evidence preserved |
| 194 | recursive-cleanup | nested exact quarantine | remove only exact proven regular files/directories; nested quarantine ordinary; unsafe evidence preserved |
| 195 | recursive-cleanup | nested ordinary hidden entry | remove only exact proven regular files/directories; nested quarantine ordinary; unsafe evidence preserved |
| 196 | recursive-cleanup | nested FIFO | remove only exact proven regular files/directories; nested quarantine ordinary; unsafe evidence preserved |
| 197 | recursive-cleanup | nested symlink | remove only exact proven regular files/directories; nested quarantine ordinary; unsafe evidence preserved |
| 198 | quarantine-collision | 0 | fresh 16-byte lowercase-hex name; retry collision at most 16, no overwrite fallback |
| 199 | quarantine-collision | 1 | fresh 16-byte lowercase-hex name; retry collision at most 16, no overwrite fallback |
| 200 | quarantine-collision | 2 | fresh 16-byte lowercase-hex name; retry collision at most 16, no overwrite fallback |
| 201 | quarantine-collision | 15 | fresh 16-byte lowercase-hex name; retry collision at most 16, no overwrite fallback |
| 202 | quarantine-collision | 16 | fresh 16-byte lowercase-hex name; retry collision at most 16, no overwrite fallback |
| 203 | capture-mismatch | regular file replacement | atomic capture detects descriptor mismatch, no unlink, no-replace rollback, strict parent sync |
| 204 | capture-mismatch | symlink replacement | atomic capture detects descriptor mismatch, no unlink, no-replace rollback, strict parent sync |
| 205 | capture-mismatch | hardlink replacement | atomic capture detects descriptor mismatch, no unlink, no-replace rollback, strict parent sync |
| 206 | capture-mismatch | empty directory replacement | atomic capture detects descriptor mismatch, no unlink, no-replace rollback, strict parent sync |
| 207 | capture-mismatch | nonempty directory replacement | atomic capture detects descriptor mismatch, no unlink, no-replace rollback, strict parent sync |
| 208 | capture-mismatch | FIFO replacement | atomic capture detects descriptor mismatch, no unlink, no-replace rollback, strict parent sync |
| 209 | capture-mismatch | socket replacement | atomic capture detects descriptor mismatch, no unlink, no-replace rollback, strict parent sync |
| 210 | capture-mismatch | device replacement | atomic capture detects descriptor mismatch, no unlink, no-replace rollback, strict parent sync |
| 211 | capture-rollback | rollback destination absent | safe rollback or preserve quarantine evidence and return RollbackFailed/CleanupIncomplete |
| 212 | capture-rollback | rollback destination recreated | safe rollback or preserve quarantine evidence and return RollbackFailed/CleanupIncomplete |
| 213 | capture-rollback | rollback rename EINTR then success | safe rollback or preserve quarantine evidence and return RollbackFailed/CleanupIncomplete |
| 214 | capture-rollback | rollback no-replace collision | safe rollback or preserve quarantine evidence and return RollbackFailed/CleanupIncomplete |
| 215 | capture-rollback | rollback identity unprovable | safe rollback or preserve quarantine evidence and return RollbackFailed/CleanupIncomplete |
| 216 | regular-file-order | observe | operation remains in exact specified order; count increments only after durability |
| 217 | regular-file-order | open | operation remains in exact specified order; count increments only after durability |
| 218 | regular-file-order | stable proof | operation remains in exact specified order; count increments only after durability |
| 219 | regular-file-order | capture | operation remains in exact specified order; count increments only after durability |
| 220 | regular-file-order | quarantine identity | operation remains in exact specified order; count increments only after durability |
| 221 | regular-file-order | unlink | operation remains in exact specified order; count increments only after durability |
| 222 | regular-file-order | absence proof | operation remains in exact specified order; count increments only after durability |
| 223 | regular-file-order | retained nlink zero | operation remains in exact specified order; count increments only after durability |
| 224 | regular-file-order | parent fsync | operation remains in exact specified order; count increments only after durability |
| 225 | regular-file-order | counter increment | operation remains in exact specified order; count increments only after durability |
| 226 | directory-order | recursive cleanup | operation remains in exact specified order; count increments only after durability |
| 227 | directory-order | empty rescan | operation remains in exact specified order; count increments only after durability |
| 228 | directory-order | child fsync | operation remains in exact specified order; count increments only after durability |
| 229 | directory-order | capture | operation remains in exact specified order; count increments only after durability |
| 230 | directory-order | quarantine identity | operation remains in exact specified order; count increments only after durability |
| 231 | directory-order | post-capture empty rescan | operation remains in exact specified order; count increments only after durability |
| 232 | directory-order | rmdir | operation remains in exact specified order; count increments only after durability |
| 233 | directory-order | absence proof | operation remains in exact specified order; count increments only after durability |
| 234 | directory-order | parent fsync | operation remains in exact specified order; count increments only after durability |
| 235 | directory-order | counter increment | operation remains in exact specified order; count increments only after durability |
| 236 | stale-root-order | lock proof | published names never targeted; counters update only after durable root removal |
| 237 | stale-root-order | bundle identity | published names never targeted; counters update only after durable root removal |
| 238 | stale-root-order | recursive cleanup | published names never targeted; counters update only after durable root removal |
| 239 | stale-root-order | empty rescan | published names never targeted; counters update only after durable root removal |
| 240 | stale-root-order | root fsync | published names never targeted; counters update only after durable root removal |
| 241 | stale-root-order | fresh capture | published names never targeted; counters update only after durable root removal |
| 242 | stale-root-order | root identity | published names never targeted; counters update only after durable root removal |
| 243 | stale-root-order | rmdir | published names never targeted; counters update only after durable root removal |
| 244 | stale-root-order | original/quarantine absent | published names never targeted; counters update only after durable root removal |
| 245 | stale-root-order | bundle fsync | published names never targeted; counters update only after durable root removal |
| 246 | stale-root-order | workspace counter | published names never targeted; counters update only after durable root removal |
| 247 | crash-recovery | crash before capture | exact quarantine is recoverable next run; malformed reserved evidence blocks new backup |
| 248 | crash-recovery | crash after top-level capture | exact quarantine is recoverable next run; malformed reserved evidence blocks new backup |
| 249 | crash-recovery | crash after child unlink | exact quarantine is recoverable next run; malformed reserved evidence blocks new backup |
| 250 | crash-recovery | crash before parent fsync | exact quarantine is recoverable next run; malformed reserved evidence blocks new backup |
| 251 | crash-recovery | next run sees exact quarantine | exact quarantine is recoverable next run; malformed reserved evidence blocks new backup |
| 252 | crash-recovery | next run sees malformed quarantine | exact quarantine is recoverable next run; malformed reserved evidence blocks new backup |
| 253 | manager-failure | stale factory failure | nil result, exact NSError, main queue exactly once, no current workspace or live cleanup |
| 254 | manager-failure | initial stale identity failure | nil result, exact NSError, main queue exactly once, no current workspace or live cleanup |
| 255 | manager-failure | stale cleanup failure | nil result, exact NSError, main queue exactly once, no current workspace or live cleanup |
| 256 | manager-failure | final stale identity failure | nil result, exact NSError, main queue exactly once, no current workspace or live cleanup |
| 257 | manager-order | lock factory | stale cleanup is after lock and before all discovery/source/timestamp/workspace/output/producer work |
| 258 | manager-order | initial lock validation | stale cleanup is after lock and before all discovery/source/timestamp/workspace/output/producer work |
| 259 | manager-order | stale factory | stale cleanup is after lock and before all discovery/source/timestamp/workspace/output/producer work |
| 260 | manager-order | stale initial validation | stale cleanup is after lock and before all discovery/source/timestamp/workspace/output/producer work |
| 261 | manager-order | stale execution | stale cleanup is after lock and before all discovery/source/timestamp/workspace/output/producer work |
| 262 | manager-order | stale final validation | stale cleanup is after lock and before all discovery/source/timestamp/workspace/output/producer work |
| 263 | manager-order | tar discovery | stale cleanup is after lock and before all discovery/source/timestamp/workspace/output/producer work |
| 264 | manager-order | source resolution | stale cleanup is after lock and before all discovery/source/timestamp/workspace/output/producer work |
| 265 | manager-order | timestamp | stale cleanup is after lock and before all discovery/source/timestamp/workspace/output/producer work |
| 266 | manager-order | backup UUID | stale cleanup is after lock and before all discovery/source/timestamp/workspace/output/producer work |
| 267 | manager-order | workspace factory | stale cleanup is after lock and before all discovery/source/timestamp/workspace/output/producer work |
| 268 | list-integration | invalid bundleID | return @[] for invalid/failure; otherwise one discovery call with current-first roots |
| 269 | list-integration | empty bundleID | return @[] for invalid/failure; otherwise one discovery call with current-first roots |
| 270 | list-integration | current root only | return @[] for invalid/failure; otherwise one discovery call with current-first roots |
| 271 | list-integration | current and distinct legacy roots | return @[] for invalid/failure; otherwise one discovery call with current-first roots |
| 272 | list-integration | lexically identical roots | return @[] for invalid/failure; otherwise one discovery call with current-first roots |
| 273 | list-integration | discovery success | return @[] for invalid/failure; otherwise one discovery call with current-first roots |
| 274 | list-integration | systemic discovery failure | return @[] for invalid/failure; otherwise one discovery call with current-first roots |
| 275 | non-regression | warnings sequence | byte/count/ordering behavior preserved as documented |
| 276 | non-regression | debug sequence | byte/count/ordering behavior preserved as documented |
| 277 | non-regression | Preferences semantics | byte/count/ordering behavior preserved as documented |
| 278 | non-regression | Keychain behavior | byte/count/ordering behavior preserved as documented |
| 279 | non-regression | manifest v4 | byte/count/ordering behavior preserved as documented |
| 280 | non-regression | publication no-replace | byte/count/ordering behavior preserved as documented |
| 281 | non-regression | live cleanup funnel 33 | byte/count/ordering behavior preserved as documented |
| 282 | non-regression | Restore v2/v3/v4 | byte/count/ordering behavior preserved as documented |
| 283 | non-regression | readManifest body | byte/count/ordering behavior preserved as documented |
| 284 | non-regression | UI | byte/count/ordering behavior preserved as documented |
| 285 | non-regression | Makefile | byte/count/ordering behavior preserved as documented |
## Protected production SHA-256 before/after
Protected workspace-byte hashes use the same Windows checkout representation before and after the final implementation audit. These files were never edited by TASK-3.10; Git baseline diff outside authorized files is also empty.

| File | Before SHA-256 | After SHA-256 | Bytes |
|---|---|---|---:|
| `.DS_Store` | `f4f3698d1ec6f68d7e09216183fe633be14d588a3f41f247b437bf03cf1228e1` | `f4f3698d1ec6f68d7e09216183fe633be14d588a3f41f247b437bf03cf1228e1` | 14340 |
| `Agent.md` | `23a29d59fac7fc30d40b6a7c8387d0413d90d400fba88fbafb515476ba317336` | `23a29d59fac7fc30d40b6a7c8387d0413d90d400fba88fbafb515476ba317336` | 6521 |
| `AppDataBackupManager.h` | `b19c1c61e6df642468d713dede5a0c0bd0dbb6a0ac72d98ad6878d3cae1f2e75` | `b19c1c61e6df642468d713dede5a0c0bd0dbb6a0ac72d98ad6878d3cae1f2e75` | 1442 |
| `AppDataBackupRestoreViewController.h` | `b470e92a732dca1c97b161f802baf1d3ea8d39706087648e7fc697b63eeba5cf` | `b470e92a732dca1c97b161f802baf1d3ea8d39706087648e7fc697b63eeba5cf` | 336 |
| `AppDataBackupRestoreViewController.m` | `48e86f63aeeb6626858fe13fed6487ef36e128f0f0fde173120abb9108bd7a96` | `48e86f63aeeb6626858fe13fed6487ef36e128f0f0fde173120abb9108bd7a96` | 28132 |
| `AppDataCleaner.h` | `b32a62280c2df60a33658e7ec9193b76802d989c984c42193f045a94365c915e` | `b32a62280c2df60a33658e7ec9193b76802d989c984c42193f045a94365c915e` | 4768 |
| `AppDataCleaner.m` | `69549666233bbbd812f16ba5abae9bfa875e5d85723a2a8f82d63b54332d4c93` | `69549666233bbbd812f16ba5abae9bfa875e5d85723a2a8f82d63b54332d4c93` | 370484 |
| `AppEntitlementsReader.h` | `c3baaeee968e61283f2e6e76ad04855815db9e8872a1814cd449d177c692e94e` | `c3baaeee968e61283f2e6e76ad04855815db9e8872a1814cd449d177c692e94e` | 1061 |
| `AppEntitlementsReader.m` | `0b53c3e24caaff5db6ceee2ae89e85ac8d4c7a7fa826cfbe814ef62c56448797` | `0b53c3e24caaff5db6ceee2ae89e85ac8d4c7a7fa826cfbe814ef62c56448797` | 11626 |
| `AppGroupContainerResolver.h` | `c18f6e6dd09d19dd49564d442c956eb3be4a153118faff392cdd899846263c97` | `c18f6e6dd09d19dd49564d442c956eb3be4a153118faff392cdd899846263c97` | 1356 |
| `AppGroupContainerResolver.m` | `11646d96beec86f070ea49e0a803fb1bc669bc48af56135f1acd7c39a5439df1` | `11646d96beec86f070ea49e0a803fb1bc669bc48af56135f1acd7c39a5439df1` | 11499 |
| `AppVersionManager.h` | `bab65a2d67128d4dd4b2ee061214f0732d1335928a7e599d469a707e4c59ecd2` | `bab65a2d67128d4dd4b2ee061214f0732d1335928a7e599d469a707e4c59ecd2` | 1295 |
| `AppVersionManager.m` | `2096f05e3c5d53947ce4dfdc08e3d9015af96441719c455f74944cd8615afd91` | `2096f05e3c5d53947ce4dfdc08e3d9015af96441719c455f74944cd8615afd91` | 15049 |
| `AppVersionSpoofingViewController.h` | `011c95fb8f776d6fae961faa94d1b0ff63bc3a1d81a0b222db9d2db8f81bbb1d` | `011c95fb8f776d6fae961faa94d1b0ff63bc3a1d81a0b222db9d2db8f81bbb1d` | 678 |
| `AppVersionSpoofingViewController.m` | `04e55427fc60c91c3a87a3a780161078b1ff643728e3bf8c4bc9ad3ac0eff6ed` | `04e55427fc60c91c3a87a3a780161078b1ff643728e3bf8c4bc9ad3ac0eff6ed` | 85181 |
| `Assets.xcassets/.DS_Store` | `dd93a4f43f346f9e8065cbfb6c3fb69910f2f284de52be4db2cfb2444895390a` | `dd93a4f43f346f9e8065cbfb6c3fb69910f2f284de52be4db2cfb2444895390a` | 6148 |
| `Assets.xcassets/AppIcon.appiconset/114.png` | `166c1096529e278504a87b29a4d38d2e0161bc204d2d040b9ad8609d4fc7a50f` | `166c1096529e278504a87b29a4d38d2e0161bc204d2d040b9ad8609d4fc7a50f` | 8495 |
| `Assets.xcassets/AppIcon.appiconset/120.png` | `6dc938664f361ba919f2c77e6b0b576e73151a687f46144022345cb8261c34b2` | `6dc938664f361ba919f2c77e6b0b576e73151a687f46144022345cb8261c34b2` | 9368 |
| `Assets.xcassets/AppIcon.appiconset/180.png` | `6ca7f490751306e8f228bfcfc2fe75bddd348c68e37286b9830915c8e559efc0` | `6ca7f490751306e8f228bfcfc2fe75bddd348c68e37286b9830915c8e559efc0` | 17711 |
| `Assets.xcassets/AppIcon.appiconset/29.png` | `744b7d04bb3fc1a604aab8e0c226db5511e57e836eac3ae19f9393f5dc579d51` | `744b7d04bb3fc1a604aab8e0c226db5511e57e836eac3ae19f9393f5dc579d51` | 1323 |
| `Assets.xcassets/AppIcon.appiconset/40.png` | `009124d0d893d71e2e9a131acbbc2d8a60dc260d743bdda73d4009b948039fa1` | `009124d0d893d71e2e9a131acbbc2d8a60dc260d743bdda73d4009b948039fa1` | 2181 |
| `Assets.xcassets/AppIcon.appiconset/57.png` | `800c14a931ca8b7b6b2a5bdf6514d982e190e1ce62313e3ec928ef1a485e4e13` | `800c14a931ca8b7b6b2a5bdf6514d982e190e1ce62313e3ec928ef1a485e4e13` | 3277 |
| `Assets.xcassets/AppIcon.appiconset/58.png` | `cca475fd7868d52db5451b870d1451a4ecc4d742f86c7b57a64ee9da16ae42d5` | `cca475fd7868d52db5451b870d1451a4ecc4d742f86c7b57a64ee9da16ae42d5` | 3350 |
| `Assets.xcassets/AppIcon.appiconset/60.png` | `89074f9c04cfc686b1522ec7be34d2cd6a2d378b948747ae1d5945a9fe056d5f` | `89074f9c04cfc686b1522ec7be34d2cd6a2d378b948747ae1d5945a9fe056d5f` | 3536 |
| `Assets.xcassets/AppIcon.appiconset/80.png` | `413476ef167e7507abca272e00adfe6654fed084f82b22a67df41e9eae28b883` | `413476ef167e7507abca272e00adfe6654fed084f82b22a67df41e9eae28b883` | 5273 |
| `Assets.xcassets/AppIcon.appiconset/87.png` | `72e90989084a130368405d67a6be27aef16014bb1c06a2dbb0f6afe4470a16b7` | `72e90989084a130368405d67a6be27aef16014bb1c06a2dbb0f6afe4470a16b7` | 5820 |
| `Assets.xcassets/AppIcon.appiconset/Contents.json` | `eb58f836a1ae5cdb9b42d5f6877f76ba678bf7310ffe1e0478bb39530c7425f6` | `eb58f836a1ae5cdb9b42d5f6877f76ba678bf7310ffe1e0478bb39530c7425f6` | 1655 |
| `Assets.xcassets/AppIcon.appiconset/Thumbs.db` | `d8108e4360bcc91b08e0ea8699131d923ea32bda8672a5ea5095c20b8afecf5f` | `d8108e4360bcc91b08e0ea8699131d923ea32bda8672a5ea5095c20b8afecf5f` | 3584 |
| `BackupKeychainGroupsViewController.h` | `fc77d536ab2a573b598ac7ff72339a63229d68f15ae239b827cb4dd2a78c2377` | `fc77d536ab2a573b598ac7ff72339a63229d68f15ae239b827cb4dd2a78c2377` | 159 |
| `BackupKeychainGroupsViewController.m` | `2f0590d7b51b05733f92c9df19c93953c2ab14fc8ca7380c43b4126ea60c4ccf` | `2f0590d7b51b05733f92c9df19c93953c2ab14fc8ca7380c43b4126ea60c4ccf` | 9567 |
| `BottomButtons.h` | `1c31f5cf5e62bda2cd580d9c7b1b2471a1218e6d8c1c330ae081c9081c49d325` | `1c31f5cf5e62bda2cd580d9c7b1b2471a1218e6d8c1c330ae081c9081c49d325` | 849 |
| `BottomButtons.m` | `025c32bfcdc79f5c81c0ad6d93be0bc1ba02f797b56a44ed62e915c62e26536b` | `025c32bfcdc79f5c81c0ad6d93be0bc1ba02f797b56a44ed62e915c62e26536b` | 24605 |
| `CommandRunner.h` | `63b88cf788fa8c981419f2c36f9375d1ed6e55190143c3c4e16b0972fe1d52bf` | `63b88cf788fa8c981419f2c36f9375d1ed6e55190143c3c4e16b0972fe1d52bf` | 1562 |
| `CommandRunner.m` | `2d5d68cd307ab150d85a28db69dd5a6169c40f78b3eb6fe49468bdaae2475030` | `2d5d68cd307ab150d85a28db69dd5a6169c40f78b3eb6fe49468bdaae2475030` | 49583 |
| `ContainerManager.h` | `d1c5ac27362d01b91fee79e6c963e23d52eb1b0b4ee22d9030f9c7d1495e78c1` | `d1c5ac27362d01b91fee79e6c963e23d52eb1b0b4ee22d9030f9c7d1495e78c1` | 1109 |
| `ContainerManager.m` | `f49a397e9c1c9122f3cfcfbabda6932b3864f2dbd2855e702b7913c2318bece9` | `f49a397e9c1c9122f3cfcfbabda6932b3864f2dbd2855e702b7913c2318bece9` | 4393 |
| `CopyHelper.h` | `d318b6795e3d11414e8e79e0d15441b46dd9e34f7ce88e42d4809635bee786d9` | `d318b6795e3d11414e8e79e0d15441b46dd9e34f7ce88e42d4809635bee786d9` | 531 |
| `CopyHelper.m` | `67ef46d464cb4a1abc839b97aaaefd6ae259a9858f0b46ac062bb396848abbc1` | `67ef46d464cb4a1abc839b97aaaefd6ae259a9858f0b46ac062bb396848abbc1` | 6147 |
| `DEBIAN/postinst` | `672605bb1f4db0ab20e7a9ed08741597ec89f91a5d19be04ddca12ba75024a72` | `672605bb1f4db0ab20e7a9ed08741597ec89f91a5d19be04ddca12ba75024a72` | 4119 |
| `DEBIAN/preinst` | `c5da98965be1131bb53af46b1f4ab17be0fa45aba9881550c3c6f497bba9e30e` | `c5da98965be1131bb53af46b1f4ab17be0fa45aba9881550c3c6f497bba9e30e` | 198 |
| `DEBIAN/prerm` | `cf8dbdff236c16a3e219a18e9a28a24370781d4315821da45c26c53f94ab22d6` | `cf8dbdff236c16a3e219a18e9a28a24370781d4315821da45c26c53f94ab22d6` | 126 |
| `DeviceSpecificSpoofingViewController+EditLabel.h` | `1cda7513c54b5af56a8ab8faa015c529cdb723597ae22e1f6949ebff72653369` | `1cda7513c54b5af56a8ab8faa015c529cdb723597ae22e1f6949ebff72653369` | 161 |
| `DeviceSpecificSpoofingViewController+EditLabel.m` | `eb54be2f1c94b9656ebdd52e5b9bae4f9284d369bcaa223384fa490a2cbb8929` | `eb54be2f1c94b9656ebdd52e5b9bae4f9284d369bcaa223384fa490a2cbb8929` | 9198 |
| `DeviceSpecificSpoofingViewController+ProfileManagerDelegate.m` | `51dfdb0f30cb3208cd8375903f986f9597b82d34e2d9c969751238e3dd4ff63c` | `51dfdb0f30cb3208cd8375903f986f9597b82d34e2d9c969751238e3dd4ff63c` | 508 |
| `DeviceSpecificSpoofingViewController.h` | `6c7d28b87e0a0dc009a4394a074aff539a1a2e5c799811b038c3e91400cb4ef4` | `6c7d28b87e0a0dc009a4394a074aff539a1a2e5c799811b038c3e91400cb4ef4` | 134 |
| `DeviceSpecificSpoofingViewController.m` | `403624616748a13ff669e885cfe646145a05dab71a612ace675180ebc41d3ef2` | `403624616748a13ff669e885cfe646145a05dab71a612ace675180ebc41d3ef2` | 56660 |
| `DevicesViewController.h` | `6722488756616f27394308ea0c8e6399bc71c5200ccb3421a603682ccd8329e5` | `6722488756616f27394308ea0c8e6399bc71c5200ccb3421a603682ccd8329e5` | 1160 |
| `DevicesViewController.m` | `79cf759ccae76beb2ba3cbb5a90ff3a8e7f239fee97748fd019bbd499f4a6e8a` | `79cf759ccae76beb2ba3cbb5a90ff3a8e7f239fee97748fd019bbd499f4a6e8a` | 38275 |
| `DomainManagementViewController.h` | `558250c37d54ba9de744c00fa625f127cead096de1e073356837abb1f2e7aa4f` | `558250c37d54ba9de744c00fa625f127cead096de1e073356837abb1f2e7aa4f` | 112 |
| `DomainManagementViewController.m` | `304191541ce30d76ca68b4bf134fabc9db4a9df63b8bafefb90ceaf41a93d66d` | `304191541ce30d76ca68b4bf134fabc9db4a9df63b8bafefb90ceaf41a93d66d` | 30905 |
| `DoorDashOrderViewController.h` | `c381a89fb9cad521fd8ccd2492a6ff9592223f631cabf82c7b0701a8d10f7eab` | `c381a89fb9cad521fd8ccd2492a6ff9592223f631cabf82c7b0701a8d10f7eab` | 668 |
| `DoorDashOrderViewController.m` | `1fa89a2df85125dba4de371c28febf138179cfc188e45894853a49a08c09d4a3` | `1fa89a2df85125dba4de371c28febf138179cfc188e45894853a49a08c09d4a3` | 37685 |
| `DownloadResourcesViewController.h` | `4106923a6377598b9a40a214b99c799a69a8cb25959ffe9cc23f9b0af55b342f` | `4106923a6377598b9a40a214b99c799a69a8cb25959ffe9cc23f9b0af55b342f` | 96 |
| `DownloadResourcesViewController.m` | `c561ea7c67518b62bf2e91cdcd11c6dd1540f881e1d7887aa3ebe4bc81670deb` | `c561ea7c67518b62bf2e91cdcd11c6dd1540f881e1d7887aa3ebe4bc81670deb` | 2456 |
| `FileManagerViewController.h` | `3434af2ed0adfb193198757611ca465792442b0b76dfa4d48d7e3e2b7c0abf64` | `3434af2ed0adfb193198757611ca465792442b0b76dfa4d48d7e3e2b7c0abf64` | 658 |
| `FileManagerViewController.m` | `bb2a6f965ede7581ab658d7300e0d76ce8b96ce1bc83236ae2a7dff9a5728887` | `bb2a6f965ede7581ab658d7300e0d76ce8b96ce1bc83236ae2a7dff9a5728887` | 55902 |
| `FixVersionAppsViewController.h` | `d62d7097d8c958218b12354802b4af74f3ca0ae23f95056f1cae6f323adfb749` | `d62d7097d8c958218b12354802b4af74f3ca0ae23f95056f1cae6f323adfb749` | 93 |
| `FixVersionAppsViewController.m` | `c7b82233db03c7d29ae5640228ec987e80f75a1d4fe3805348c43d02e9072cf5` | `c7b82233db03c7d29ae5640228ec987e80f75a1d4fe3805348c43d02e9072cf5` | 7764 |
| `FreezeManager.h` | `bdf75483157b774cca85e65c5e93bee581a8ef6be0f5f378070e04d26f43b894` | `bdf75483157b774cca85e65c5e93bee581a8ef6be0f5f378070e04d26f43b894` | 385 |
| `FreezeManager.m` | `00473a0fab8fda61235b66058152697b68a60deff46a3f8d4b209bb3574845c4` | `00473a0fab8fda61235b66058152697b68a60deff46a3f8d4b209bb3574845c4` | 8975 |
| `Icon.png` | `6dc938664f361ba919f2c77e6b0b576e73151a687f46144022345cb8261c34b2` | `6dc938664f361ba919f2c77e6b0b576e73151a687f46144022345cb8261c34b2` | 9368 |
| `Improvement_Plan.md` | `6707b1154da25fb64f56380146a0172ec1d2e4d22d4242a90a81f953252a67c3` | `6707b1154da25fb64f56380146a0172ec1d2e4d22d4242a90a81f953252a67c3` | 12526 |
| `Info.plist` | `2d017f405d32126d2102999838a77984a5c7bffc39be728ed479487cd903f477` | `2d017f405d32126d2102999838a77984a5c7bffc39be728ed479487cd903f477` | 7202 |
| `KeychainGroupsViewController.h` | `48945d11fbf9ee4e9921140fc7d674abacbed3076db2b514fc641b6ac118a50b` | `48945d11fbf9ee4e9921140fc7d674abacbed3076db2b514fc641b6ac118a50b` | 153 |
| `KeychainGroupsViewController.m` | `0e25b51199550964a5f743e50dc49641d161efd347973d49f58cc861a6260d35` | `0e25b51199550964a5f743e50dc49641d161efd347973d49f58cc861a6260d35` | 10227 |
| `KeychainHelper/KeychainBackupHelper.h` | `dbf0d5a4bdfc1df3e4f74b103968e018d0932f89c245bae8f260b196c0664281` | `dbf0d5a4bdfc1df3e4f74b103968e018d0932f89c245bae8f260b196c0664281` | 4280 |
| `KeychainHelper/KeychainBackupHelper.m` | `203884bf8d009a01a936acb5371c9316f7a0d6212b0d226f7f8a7661d51d122c` | `203884bf8d009a01a936acb5371c9316f7a0d6212b0d226f7f8a7661d51d122c` | 27970 |
| `KeychainHelper/backup_helper.m` | `9f4e2c1cd0d7ebb7afef93d537e759858d60d2ae2ddd89b7b535ec611d437b83` | `9f4e2c1cd0d7ebb7afef93d537e759858d60d2ae2ddd89b7b535ec611d437b83` | 14129 |
| `LaunchScreen.storyboard` | `36cf5911aab28984a57eecb7544336636bd75a763961075505be9720bd1f23bb` | `36cf5911aab28984a57eecb7544336636bd75a763961075505be9720bd1f23bb` | 3134 |
| `Makefile` | `717465ec5894548e894412aa7f4205f4b8d5ac7e9d13339327477dd686d6c9a9` | `717465ec5894548e894412aa7f4205f4b8d5ac7e9d13339327477dd686d6c9a9` | 9146 |
| `Making` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 |
| `MatrixRainView.h` | `8a82ddcdcb831793821158d219feafef052540c09ecead96a29d6c63fe2ca94c` | `8a82ddcdcb831793821158d219feafef052540c09ecead96a29d6c63fe2ca94c` | 273 |
| `Newplan.md` | `d2f5a2d387bd4e513f9981f6071b889c3ff723043d2c661ccebe7bafc55df204` | `d2f5a2d387bd4e513f9981f6071b889c3ff723043d2c661ccebe7bafc55df204` | 17391 |
| `PXAppGroupRestoreTargetPlan.h` | `565924464aafb15836a4506de0336f62c2eb0986f7fa7ebd1839d98c48e888d3` | `565924464aafb15836a4506de0336f62c2eb0986f7fa7ebd1839d98c48e888d3` | 2039 |
| `PXAppGroupRestoreTargetPlan.m` | `c03b64aa48b59ff1fb380ff8fcfb0b6aba468739921fe7b151e8d8445bc8731d` | `c03b64aa48b59ff1fb380ff8fcfb0b6aba468739921fe7b151e8d8445bc8731d` | 18688 |
| `PXAppGroupRestoreTransaction.h` | `cd329b3f67433214b36d195719e337cc951204c774dd65bbe379eb8936a33412` | `cd329b3f67433214b36d195719e337cc951204c774dd65bbe379eb8936a33412` | 2235 |
| `PXAppGroupRestoreTransaction.m` | `842bf9676fdac4c31433f966b81b2b93c82d03225d7f046d7e464a3b402bfbd6` | `842bf9676fdac4c31433f966b81b2b93c82d03225d7f046d7e464a3b402bfbd6` | 138376 |
| `PXBackupArchiveValidator.h` | `661258274d798bfd67356d472334cfffcc1da6a911278ae6e956a66e0cf4b05b` | `661258274d798bfd67356d472334cfffcc1da6a911278ae6e956a66e0cf4b05b` | 2361 |
| `PXBackupArchiveValidator.m` | `01c8c628453b8f67853a84ebf9c5511c6a9af454c80bc476da1d9f685eaa306e` | `01c8c628453b8f67853a84ebf9c5511c6a9af454c80bc476da1d9f685eaa306e` | 89098 |
| `PXBackupArtifactPolicy.h` | `52da8d6a0537d6a9647af13b9a992d5e131d6405f3ea2759f6a811b7ad90f80f` | `52da8d6a0537d6a9647af13b9a992d5e131d6405f3ea2759f6a811b7ad90f80f` | 1648 |
| `PXBackupArtifactPolicy.m` | `c40df7376b918cadf79508a9cb45aa04bf27390e015e80e442a41764be13f7bc` | `c40df7376b918cadf79508a9cb45aa04bf27390e015e80e442a41764be13f7bc` | 4536 |
| `PXBackupArtifactVerifier.h` | `6831f6fd7b52eda12d6407c744e8f4fe5b3fcf101567185930ce53246da9c7a0` | `6831f6fd7b52eda12d6407c744e8f4fe5b3fcf101567185930ce53246da9c7a0` | 1949 |
| `PXBackupArtifactVerifier.m` | `81a828d3d3365430a308ccf7e8ca655a5efa5496d97caae936ebc1fa303701f1` | `81a828d3d3365430a308ccf7e8ca655a5efa5496d97caae936ebc1fa303701f1` | 43911 |
| `PXBackupArtifactWriter.h` | `5e91f6db0b8921f6980e4db53eb06edf2b505be05eacc16334bca6f7a80bb1e8` | `5e91f6db0b8921f6980e4db53eb06edf2b505be05eacc16334bca6f7a80bb1e8` | 2948 |
| `PXBackupArtifactWriter.m` | `0362e20b17155d1182b528779c749bd23ffa4614436e03231a8c3e1ac9b4f330` | `0362e20b17155d1182b528779c749bd23ffa4614436e03231a8c3e1ac9b4f330` | 83333 |
| `PXBackupBundleLock.h` | `6a094c91f862db366d2bb976d889645971dd72f7a1781a027df9d205318c2ce9` | `6a094c91f862db366d2bb976d889645971dd72f7a1781a027df9d205318c2ce9` | 1714 |
| `PXBackupBundleLock.m` | `563cb607b41ba12e6620b7a8a72e999a84715fd64b671555d512e8440798613b` | `563cb607b41ba12e6620b7a8a72e999a84715fd64b671555d512e8440798613b` | 36342 |
| `PXBackupDirectoryPublisher.h` | `014be6af62da52efab0f442d93814a88634953dbc56ae38d24f932d873834e39` | `014be6af62da52efab0f442d93814a88634953dbc56ae38d24f932d873834e39` | 2889 |
| `PXBackupDirectoryPublisher.m` | `0f85750abf3ef1f2043be5af8708f340cccb20606188b09f63843cc5963d8223` | `0f85750abf3ef1f2043be5af8708f340cccb20606188b09f63843cc5963d8223` | 70795 |
| `PXBackupFailureCleanup.h` | `ee242afc8ca4aad39dcfe240e168bcc4d52e72abb63a835981f306c71f89466d` | `ee242afc8ca4aad39dcfe240e168bcc4d52e72abb63a835981f306c71f89466d` | 2377 |
| `PXBackupFailureCleanup.m` | `669ac9cc24489cb388058afd54d8fd63e28057220fa2ea9020aa93431e8d3138` | `669ac9cc24489cb388058afd54d8fd63e28057220fa2ea9020aa93431e8d3138` | 80668 |
| `PXBackupManifestV4.h` | `4e9c679d8d4a69f68111bb848467a7290a8760330b310ef4c2a25941612e6054` | `4e9c679d8d4a69f68111bb848467a7290a8760330b310ef4c2a25941612e6054` | 2354 |
| `PXBackupManifestV4.m` | `db7e09ceeee46049ff180e88293e6088b652b8ae1c231ad2c3ec825cd5bd9fd7` | `db7e09ceeee46049ff180e88293e6088b652b8ae1c231ad2c3ec825cd5bd9fd7` | 44234 |
| `PXBackupManifestValidator.h` | `6bf479c032e044a89a9d028517a50692c7d95ccef35f78e92a782653a4dcc836` | `6bf479c032e044a89a9d028517a50692c7d95ccef35f78e92a782653a4dcc836` | 945 |
| `PXBackupManifestValidator.m` | `e3403920f816cbf6c8c1c135d835786fa83f56a36901a9e41427e86cf6bb1820` | `e3403920f816cbf6c8c1c135d835786fa83f56a36901a9e41427e86cf6bb1820` | 91751 |
| `PXBackupManifestWriter.h` | `a8eef3991f2e9176d0ddd73aa007c7e2442be6b2e257b6576dfa5db680a2f546` | `a8eef3991f2e9176d0ddd73aa007c7e2442be6b2e257b6576dfa5db680a2f546` | 2431 |
| `PXBackupManifestWriter.m` | `005c64ea37718f3c8c4a0ac97422441bb5e1393d7cfe8082aecd1e14d519729c` | `005c64ea37718f3c8c4a0ac97422441bb5e1393d7cfe8082aecd1e14d519729c` | 54069 |
| `PXBackupPublicationWorkspace.h` | `7ee3ce30d84edd6907cdc9fd3fb812dd768d03decb3ee0d50d464d17c4ae0851` | `7ee3ce30d84edd6907cdc9fd3fb812dd768d03decb3ee0d50d464d17c4ae0851` | 1869 |
| `PXBackupPublicationWorkspace.m` | `39974a40b4bf89f31ac9cbf1e8dfa716a94a0fd13e39d9c7539a02d14d2781f6` | `39974a40b4bf89f31ac9cbf1e8dfa716a94a0fd13e39d9c7539a02d14d2781f6` | 48086 |
| `PXClearRequest.h` | `d87402ee3720f1723977e4deb3d78bc1de87362948dfe585b5ed98f6447ae26b` | `d87402ee3720f1723977e4deb3d78bc1de87362948dfe585b5ed98f6447ae26b` | 1288 |
| `PXClearRequest.m` | `afc763afc3306d422ef67ef3bd28a2a1a5741a64ea6078ee28f56f5d5901c790` | `afc763afc3306d422ef67ef3bd28a2a1a5741a64ea6078ee28f56f5d5901c790` | 4389 |
| `PXClearResult.h` | `cedc6e364ebc4bf25acd8d128938db114033ca076750d2fade8e183488b2b592` | `cedc6e364ebc4bf25acd8d128938db114033ca076750d2fade8e183488b2b592` | 3467 |
| `PXClearResult.m` | `0e4bce039d6ca19f46590822bdfc938763cddc852be3045f6ada98e2fa0c5715` | `0e4bce039d6ca19f46590822bdfc938763cddc852be3045f6ada98e2fa0c5715` | 10564 |
| `PXDataContainerResolver.h` | `b2e10dc045d49d9d09e0055973885b576f9909896dd8778339e65e0e812b8f30` | `b2e10dc045d49d9d09e0055973885b576f9909896dd8778339e65e0e812b8f30` | 1290 |
| `PXDataContainerResolver.m` | `cc29adca6dc2fb30354541fdec9992b7cf7450d6cc0470c46864ecf456b4a365` | `cc29adca6dc2fb30354541fdec9992b7cf7450d6cc0470c46864ecf456b4a365` | 8332 |
| `PXDestructivePathValidator.h` | `542e158a4f04bf50125e0064fbebf02ac32f1de07508c3f32058e770f75a3c0a` | `542e158a4f04bf50125e0064fbebf02ac32f1de07508c3f32058e770f75a3c0a` | 1213 |
| `PXDestructivePathValidator.m` | `f275a60be5cab58e5d06db3dd0987948f5eab65ddd7e35e35e45927d238877cb` | `f275a60be5cab58e5d06db3dd0987948f5eab65ddd7e35e35e45927d238877cb` | 32523 |
| `PXMainDataRestoreTransaction.h` | `df444b03e0214d62e31c89094f7e0afe1037255ab6582928a608ec839466a575` | `df444b03e0214d62e31c89094f7e0afe1037255ab6582928a608ec839466a575` | 2061 |
| `PXMainDataRestoreTransaction.m` | `894c40ab599074bc6c481a5b9084c3d557c64fb101336f0495d5297234a5f3c5` | `894c40ab599074bc6c481a5b9084c3d557c64fb101336f0495d5297234a5f3c5` | 115847 |
| `PXMainDataStaging.h` | `2eaea45c166986c419b32074141e8e1f7ab6000f153e860b10b48e1405620554` | `2eaea45c166986c419b32074141e8e1f7ab6000f153e860b10b48e1405620554` | 2511 |
| `PXMainDataStaging.m` | `686fbbf5c382b9c2dfc4f5917b20993cca434a1976f098f20f98ddfa87769162` | `686fbbf5c382b9c2dfc4f5917b20993cca434a1976f098f20f98ddfa87769162` | 67751 |
| `PXOptionalRestoreStaging.h` | `b412a77d26f4e22d17083f4faa761d0dc02c4fef8e25f5aec4c2c84be86a78e4` | `b412a77d26f4e22d17083f4faa761d0dc02c4fef8e25f5aec4c2c84be86a78e4` | 4209 |
| `PXOptionalRestoreStaging.m` | `639333e3f891ee6e61cb1f486c97e54c68751439c64014c03169c37a2ea8e3f5` | `639333e3f891ee6e61cb1f486c97e54c68751439c64014c03169c37a2ea8e3f5` | 100980 |
| `PXOptionalRestoreTransaction.h` | `1d162e411824a708209c78325385cff75cea453a8097c93347f02cfb8bf2ad78` | `1d162e411824a708209c78325385cff75cea453a8097c93347f02cfb8bf2ad78` | 4050 |
| `PXOptionalRestoreTransaction.m` | `b766f73f7b49877ab589f35ae9dc7d0f89e80638526e6c5663777ac6a1a48c1c` | `b766f73f7b49877ab589f35ae9dc7d0f89e80638526e6c5663777ac6a1a48c1c` | 240408 |
| `PXResolvedContainer.h` | `6ba935cb659ebdc5fdb8a96b13dd9f1450acb2e284267ac82e8890287a686718` | `6ba935cb659ebdc5fdb8a96b13dd9f1450acb2e284267ac82e8890287a686718` | 1691 |
| `PXResolvedContainer.m` | `a782089c0605f8d7803ffb53f746a585afb85f3ffbc9ed111f00575d77ada8fb` | `a782089c0605f8d7803ffb53f746a585afb85f3ffbc9ed111f00575d77ada8fb` | 5304 |
| `PXRestorePlan.h` | `5cc773132c009fd8eedf4069b33ab53901a530edd580e3231c9d982c60cf7643` | `5cc773132c009fd8eedf4069b33ab53901a530edd580e3231c9d982c60cf7643` | 4947 |
| `PXRestorePlan.m` | `cb6f838638a06bc9858b392d123656590291555812c63e3d0ddd4f5529d0d141` | `cb6f838638a06bc9858b392d123656590291555812c63e3d0ddd4f5529d0d141` | 48523 |
| `PXRestoreResult.h` | `cb7f2f3e40b3414d329405b1802bf6a9f245f1b660ca983d04776c0af449e69d` | `cb7f2f3e40b3414d329405b1802bf6a9f245f1b660ca983d04776c0af449e69d` | 4512 |
| `PXRestoreResult.m` | `c698a854589731f0987379c324d02729f3b586fd0ac3575f9798b77d6207c2fb` | `c698a854589731f0987379c324d02729f3b586fd0ac3575f9798b77d6207c2fb` | 15842 |
| `PlistViewerViewController.h` | `84e7faeb8986573e038eb4ccd89ad69096be5bbb668c28d21701964dce1d9861` | `84e7faeb8986573e038eb4ccd89ad69096be5bbb668c28d21701964dce1d9861` | 184 |
| `PlistViewerViewController.m` | `204b5483da9c6605dd7bce780f32841f5f578a5f808cec9043dcd6158a57b5b1` | `204b5483da9c6605dd7bce780f32841f5f578a5f808cec9043dcd6158a57b5b1` | 26767 |
| `ProfileButtonsView.h` | `f684b1fd6790fcf3484195c7115441c435bcfcb0a376f8a9dcec79f71a9dcc44` | `f684b1fd6790fcf3484195c7115441c435bcfcb0a376f8a9dcec79f71a9dcc44` | 254 |
| `ProfileButtonsView.m` | `d4f7db76a846f87a5bbeda0a3360244e56a6c6da77ea38607386c62d29c92d8b` | `d4f7db76a846f87a5bbeda0a3360244e56a6c6da77ea38607386c62d29c92d8b` | 5381 |
| `ProfileCreationViewController.h` | `9a0607d0f92ac497b86435e5abdd3402f5f68e900893130a084f777e7b5429b6` | `9a0607d0f92ac497b86435e5abdd3402f5f68e900893130a084f777e7b5429b6` | 388 |
| `ProfileCreationViewController.m` | `3899ba590c6d4e222e7516c1fcfc0947c84a28f2439c84f92cefaaf9a61d4f60` | `3899ba590c6d4e222e7516c1fcfc0947c84a28f2439c84f92cefaaf9a61d4f60` | 7575 |
| `ProfileManagerViewController.h` | `d96f5b92633c1aad6ed40a6e007aa9c00e69b4b9fe7209c0ea0502c5d5b7a2f4` | `d96f5b92633c1aad6ed40a6e007aa9c00e69b4b9fe7209c0ea0502c5d5b7a2f4` | 783 |
| `ProfileManagerViewController.m` | `a26680aa7340f00b913950cd019245066d0854880839403346a965fbf832bb1a` | `a26680aa7340f00b913950cd019245066d0854880839403346a965fbf832bb1a` | 159713 |
| `ProgressHUDView.h` | `b02f257178fbb9b705ba19f49d37528126d100b968ef1bf9f91f9312c94eb8d5` | `b02f257178fbb9b705ba19f49d37528126d100b968ef1bf9f91f9312c94eb8d5` | 522 |
| `ProgressHUDView.m` | `18f60d3321c26d692e27310e8e1ef334b99a2cd8daa732234623d17006aabb98` | `18f60d3321c26d692e27310e8e1ef334b99a2cd8daa732234623d17006aabb98` | 2263 |
| `ProjectX` | `a81b074d511a8a7c94032dabd27feb7cdf43585788e559b2858b934dd2224c9e` | `a81b074d511a8a7c94032dabd27feb7cdf43585788e559b2858b934dd2224c9e` | 1691136 |
| `ProjectX.entitlements` | `224bece3b1e28d417a1b9c1f70c82aa1453d8af9562e0bc3298279aec4dc459c` | `224bece3b1e28d417a1b9c1f70c82aa1453d8af9562e0bc3298279aec4dc459c` | 1747 |
| `ProjectX.h` | `5dcd27265018819afb50b9b4d2582563f9048c773e9ced1ce7a1833d44f8fb03` | `5dcd27265018819afb50b9b4d2582563f9048c773e9ced1ce7a1833d44f8fb03` | 1623 |
| `ProjectXInstaller.h` | `9b7d06a8a0687e36187b838d9b9acd7ccc66e04d49ea97565fc924e7ea361245` | `9b7d06a8a0687e36187b838d9b9acd7ccc66e04d49ea97565fc924e7ea361245` | 1231 |
| `ProjectXInstaller.m` | `5f2d464b5f7c00c4c83a849a8a2783ed54868e9ff8290a7283824309e993b41b` | `5f2d464b5f7c00c4c83a849a8a2783ed54868e9ff8290a7283824309e993b41b` | 1898 |
| `ProjectXSceneDelegate.h` | `2e56a5014cde4c047575638be864e83e2560da885aa25a5ecb150f05b3525f5f` | `2e56a5014cde4c047575638be864e83e2560da885aa25a5ecb150f05b3525f5f` | 192 |
| `ProjectXSceneDelegate.m` | `dc056734ec81ff57484ef2e2ddddda9496b39d774ff743c42cfa6e88bbb0677e` | `dc056734ec81ff57484ef2e2ddddda9496b39d774ff743c42cfa6e88bbb0677e` | 12181 |
| `ProjectXTweak.dylib` | `e024784ca18867a8eb9924a7342da693c6fccb8af97716446a611db13dc8b171` | `e024784ca18867a8eb9924a7342da693c6fccb8af97716446a611db13dc8b171` | 945152 |
| `ProjectXTweak.plist` | `9c8559c83f6fa8a4e247caf92265adbbbe65cb4d2cdadd2fa594de4700fff2f8` | `9c8559c83f6fa8a4e247caf92265adbbbe65cb4d2cdadd2fa594de4700fff2f8` | 429 |
| `ProjectXTweak/AAA_TestCtor.m` | `3226080d60eec3c92a9966f09c4adc12b58b4211329e2106a4db460333c36b70` | `3226080d60eec3c92a9966f09c4adc12b58b4211329e2106a4db460333c36b70` | 1614 |
| `ProjectXTweak/AppContainerHooks.x` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 |
| `ProjectXTweak/AppGroupHooks.x` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 |
| `ProjectXTweak/AppInstallHooks.x` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 |
| `ProjectXTweak/AppVersionHooks.h` | `7010216dcf52c45952a5ac3be1211db49952d46f76a4ee9d98a323a4c864b96a` | `7010216dcf52c45952a5ac3be1211db49952d46f76a4ee9d98a323a4c864b96a` | 546 |
| `ProjectXTweak/AppVersionHooks.x` | `091eda3e306a0fcb5a0889d09d3af11fe491edd1d6acf5c6ca076adc069ee992` | `091eda3e306a0fcb5a0889d09d3af11fe491edd1d6acf5c6ca076adc069ee992` | 25202 |
| `ProjectXTweak/BatteryHooks.x` | `cda2451306704f7be1b8e228dea3818a661869fc2951f9bb13ed17d97e04a462` | `cda2451306704f7be1b8e228dea3818a661869fc2951f9bb13ed17d97e04a462` | 17019 |
| `ProjectXTweak/BootTimeHooks.x` | `1cf9ff3f8930a12ce53a809aa2c5e3dc8ce648836a882692f0bb2999214aedc9` | `1cf9ff3f8930a12ce53a809aa2c5e3dc8ce648836a882692f0bb2999214aedc9` | 26933 |
| `ProjectXTweak/CanvasFingerprintHooks.x` | `8d58697627269d9329490050de59d2d22409bbaadf462e85e16fbb3fa2a160f5` | `8d58697627269d9329490050de59d2d22409bbaadf462e85e16fbb3fa2a160f5` | 27600 |
| `ProjectXTweak/CoreDataHooks.x` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 |
| `ProjectXTweak/DeviceModelHooks.x` | `0523ea3f49d45037a14e319477efb936f22c049582600a649b79765a88618313` | `0523ea3f49d45037a14e319477efb936f22c049582600a649b79765a88618313` | 9012 |
| `ProjectXTweak/DeviceSpecHooks.x` | `4cc3bf32980902c66eac012b23b5bc9f3ece2efb6606a84140b99a3827a94e27` | `4cc3bf32980902c66eac012b23b5bc9f3ece2efb6606a84140b99a3827a94e27` | 81702 |
| `ProjectXTweak/DomainBlockingHooks.x` | `43130baab0454d4c0be7515b6454ba14ea1aa8327d112f15ad2d87de00999d9b` | `43130baab0454d4c0be7515b6454ba14ea1aa8327d112f15ad2d87de00999d9b` | 27065 |
| `ProjectXTweak/FirebasePerfDisableScoped.x` | `a361527514d0de6fef9bb14552f7e753dccc3a1a3ce7010302d68884d85ec844` | `a361527514d0de6fef9bb14552f7e753dccc3a1a3ce7010302d68884d85ec844` | 2515 |
| `ProjectXTweak/HookOwnership.h` | `7a35059699c35fd433bbc588d1cfc7e240b4447268e9ecc94a400ae3cfd4d2da` | `7a35059699c35fd433bbc588d1cfc7e240b4447268e9ecc94a400ae3cfd4d2da` | 541 |
| `ProjectXTweak/IOSVersionHooks.x` | `bc3a7d9f7fc848399d90cf1321bcf132708f71263a2c7c509d9b20304b4fb860` | `bc3a7d9f7fc848399d90cf1321bcf132708f71263a2c7c509d9b20304b4fb860` | 112809 |
| `ProjectXTweak/JailbreakBypassHooks.x` | `989c720f92a03470a7bba9ce60f2a7b341f7a538a924a41a8ee47304da373494` | `989c720f92a03470a7bba9ce60f2a7b341f7a538a924a41a8ee47304da373494` | 142382 |
| `ProjectXTweak/KeychainHooks.x` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 |
| `ProjectXTweak/LocaleTimeZoneHooks.x` | `853fe8689c3e8173aba8d4e3b34e67fd5e3b99ea35f34cf6cf1eb2f376b215c8` | `853fe8689c3e8173aba8d4e3b34e67fd5e3b99ea35f34cf6cf1eb2f376b215c8` | 4909 |
| `ProjectXTweak/Makefile.bak` | `b509097c737be4b6eff89ff01f49cd3b690d9217e89b304be17718b1c61ec018` | `b509097c737be4b6eff89ff01f49cd3b690d9217e89b304be17718b1c61ec018` | 999 |
| `ProjectXTweak/MethodSwizzler.h` | `bf42638563a47092e76e95296d999b7bb440b2d98095957aff83a8d3c69f810e` | `bf42638563a47092e76e95296d999b7bb440b2d98095957aff83a8d3c69f810e` | 341 |
| `ProjectXTweak/MethodSwizzler.m` | `39a9324dd2fa8590f25d61b3e8f106cef5acea7d0f2784c4ab1b2f919b52e982` | `39a9324dd2fa8590f25d61b3e8f106cef5acea7d0f2784c4ab1b2f919b52e982` | 1903 |
| `ProjectXTweak/MissingSpoofHooks.x` | `ed71e70219a2e4fdc42f6cf1930bee71c83c0a565741f5afdd7ec7752c0508e1` | `ed71e70219a2e4fdc42f6cf1930bee71c83c0a565741f5afdd7ec7752c0508e1` | 9793 |
| `ProjectXTweak/MobileGestalt.h` | `a81ba122e63f9ebb143a65afa8227badd76cfd7b971fe7ee5e9aab77c8b6352b` | `a81ba122e63f9ebb143a65afa8227badd76cfd7b971fe7ee5e9aab77c8b6352b` | 11371 |
| `ProjectXTweak/NetworkConnectionTypeHooks.x` | `445e68b2a745e17922842fb620c080d83f73dc002e460b362b2e0fdf8ae487db` | `445e68b2a745e17922842fb620c080d83f73dc002e460b362b2e0fdf8ae487db` | 56573 |
| `ProjectXTweak/ObjcClassPairGuard.x` | `8d009928b014571c0aec433aac908936989e24fe848e01b38fa1b83991487ad9` | `8d009928b014571c0aec433aac908936989e24fe848e01b38fa1b83991487ad9` | 5439 |
| `ProjectXTweak/PXFileDebug.h` | `0ff94999994a071b66a1482d3b97bdacc4f31002096129b661243a774dd1bcc5` | `0ff94999994a071b66a1482d3b97bdacc4f31002096129b661243a774dd1bcc5` | 6957 |
| `ProjectXTweak/PXNativeHookCoordinator.h` | `248f78c9bc54e625d540e9ae8c3a7a4021e05fdac0a43830b669cb4dcfa625e4` | `248f78c9bc54e625d540e9ae8c3a7a4021e05fdac0a43830b669cb4dcfa625e4` | 9000 |
| `ProjectXTweak/PXNativeHookCoordinator.m` | `2ad1f7fc4b46e59ec6e4776a4eb5d9b8331da41c1fdf4b73860eabd37d4ff27d` | `2ad1f7fc4b46e59ec6e4776a4eb5d9b8331da41c1fdf4b73860eabd37d4ff27d` | 28291 |
| `ProjectXTweak/PXScope.h` | `4ebc18511d27845a0a14499406d2525cde6c32043a931857c057521222638b32` | `4ebc18511d27845a0a14499406d2525cde6c32043a931857c057521222638b32` | 1747 |
| `ProjectXTweak/PXScope.m` | `46193b6d6b3443b8b879a8e8b32b4f18ee3a4072134e4965957091fa6a4ce44f` | `46193b6d6b3443b8b879a8e8b32b4f18ee3a4072134e4965957091fa6a4ce44f` | 20405 |
| `ProjectXTweak/PasteboardHooks.x` | `2a158ee64def29488c10a78bebe7a66b07ad5b3a9e4ad8122599ea8e204cfe19` | `2a158ee64def29488c10a78bebe7a66b07ad5b3a9e4ad8122599ea8e204cfe19` | 37855 |
| `ProjectXTweak/SpringBoardLaunchHook.x` | `04b3a6f8caffae072b0bd4c7adf1f2dc5f6ef0d8772da6fcefa570e8d3dc2d55` | `04b3a6f8caffae072b0bd4c7adf1f2dc5f6ef0d8772da6fcefa570e8d3dc2d55` | 16185 |
| `ProjectXTweak/StorageHooks.x` | `315d3887f0f2aa3fc59b9b7aa5ef6b0a72e63ce248dd78097b85545f6434297a` | `315d3887f0f2aa3fc59b9b7aa5ef6b0a72e63ce248dd78097b85545f6434297a` | 41482 |
| `ProjectXTweak/ThemeHooks.x` | `3c8be122460f652f2c15f5737ab3ae96c44ff1391658191659301adfcc27c4cf` | `3c8be122460f652f2c15f5737ab3ae96c44ff1391658191659301adfcc27c4cf` | 19043 |
| `ProjectXTweak/Tweak.x` | `a8dfc1055e1973b7fe2b9f3320a754de63e4ea887e6ca5c836924f5af5bdf82f` | `a8dfc1055e1973b7fe2b9f3320a754de63e4ea887e6ca5c836924f5af5bdf82f` | 196955 |
| `ProjectXTweak/UUIDHooks.x` | `90b86d384da2c0c8cb2593ff40eff3ff5831e3ae481034888ace50cfd3d05a7d` | `90b86d384da2c0c8cb2593ff40eff3ff5831e3ae481034888ace50cfd3d05a7d` | 43164 |
| `ProjectXTweak/UberURLHooks.x` | `be5123cbfb9971807329e9d97fb881d30ac55550e68b6ba769c4da9b7f69001b` | `be5123cbfb9971807329e9d97fb881d30ac55550e68b6ba769c4da9b7f69001b` | 40212 |
| `ProjectXTweak/UserDefaultsHooks.x` | `ad6076166b161d35c82cd1418fca4d72f98df87bc5e2a46812830d21edfd6154` | `ad6076166b161d35c82cd1418fca4d72f98df87bc5e2a46812830d21edfd6154` | 26089 |
| `ProjectXTweak/VPNDetectionBypass.x` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 |
| `ProjectXTweak/WiFiHook.x` | `045c84ad29aad9520de43d8bf9c4967132c83ecee239c30f9240807fa9f5c36b` | `045c84ad29aad9520de43d8bf9c4967132c83ecee239c30f9240807fa9f5c36b` | 40848 |
| `ProjectXViewController.h` | `046a37c9ccfc33c7a46ddefd74369abfa08b8b96712093f2bffcf3e8bae8fa1c` | `046a37c9ccfc33c7a46ddefd74369abfa08b8b96712093f2bffcf3e8bae8fa1c` | 853 |
| `ProjectXViewController.m` | `b7c5293dfa5d27fdc39c36f236f76306a855eaaf4e9e028f4c2111eb68146162` | `b7c5293dfa5d27fdc39c36f236f76306a855eaaf4e9e028f4c2111eb68146162` | 372278 |
| `README.md` | `de0e61f9ee6cb9ac61e0db218ae510cf9fcc0bd84ec8f0229e76c7ed3117a0d2` | `de0e61f9ee6cb9ac61e0db218ae510cf9fcc0bd84ec8f0229e76c7ed3117a0d2` | 184 |
| `SecurityTabViewController+IPMonitorInfo.m` | `d389a7c50f1bd2fc14761d72db0c86bda7fae1d931ed9143f0a1c1ecbec57121` | `d389a7c50f1bd2fc14761d72db0c86bda7fae1d931ed9143f0a1c1ecbec57121` | 967 |
| `SecurityTabViewController.h` | `7f21e86f58fe5377f2964fba785ae65dde5e89284aca8aca334ea5322190f53d` | `7f21e86f58fe5377f2964fba785ae65dde5e89284aca8aca334ea5322190f53d` | 5441 |
| `SecurityTabViewController.m` | `9a3629b4751b6c9f1dee227a66ff61a57b8cbeed7c13b4e81dc63b314f4acbaf` | `9a3629b4751b6c9f1dee227a66ff61a57b8cbeed7c13b4e81dc63b314f4acbaf` | 293431 |
| `TabBarController+DeviceAlerts.h` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 |
| `TabBarController+DeviceAlerts.m` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 |
| `TabBarController.h` | `f71b771e6e94a716f3678744b80fef317baafd33198292fb45b16ebd022b8584` | `f71b771e6e94a716f3678744b80fef317baafd33198292fb45b16ebd022b8584` | 1019 |
| `TabBarController.m` | `09f8f74232728fb8edd4c699cf612683d04aff6bc1fdfd766970e65e7829d2eb` | `09f8f74232728fb8edd4c699cf612683d04aff6bc1fdfd766970e65e7829d2eb` | 28147 |
| `TestCtorTweak/Makefile` | `acce9155e79d225a6b892aa7b85bb33696bd6d22eed356cc4add4a0dac7de85c` | `acce9155e79d225a6b892aa7b85bb33696bd6d22eed356cc4add4a0dac7de85c` | 217 |
| `TestCtorTweak/TestCtorTweak.plist` | `c84e26f2c423b89c5f84cf847b9132079de48bbef72b1f7d8ebe96370796d61f` | `c84e26f2c423b89c5f84cf847b9132079de48bbef72b1f7d8ebe96370796d61f` | 315 |
| `TestCtorTweak/Tweak.x` | `17219fd435a7dce5cf70f59eca6a21c7f950f9e3f68578c0e560e7e16bb07924` | `17219fd435a7dce5cf70f59eca6a21c7f950f9e3f68578c0e560e7e16bb07924` | 351 |
| `ToolViewController.h` | `8b182a81a023731502ab0be3bef0076733a94fde71077486df8424c46ec01ba0` | `8b182a81a023731502ab0be3bef0076733a94fde71077486df8424c46ec01ba0` | 280 |
| `ToolViewController.m` | `46413d0c6777a0afa4df06ddcb8c10da30b9114b3e6a6db4e1abbaae3c191a2e` | `46413d0c6777a0afa4df06ddcb8c10da30b9114b3e6a6db4e1abbaae3c191a2e` | 59814 |
| `URLMonitor.h` | `2897113b7a6e98f40c72d13ccce718c289420d38199939d43a0bd76ada7caaac` | `2897113b7a6e98f40c72d13ccce718c289420d38199939d43a0bd76ada7caaac` | 727 |
| `URLMonitor.m` | `34f764be70ac6fa679f729489550556f5bc49785086932260d03b243d875be59` | `34f764be70ac6fa679f729489550556f5bc49785086932260d03b243d875be59` | 8827 |
| `UberOrderViewController.h` | `ed4f5e3011738de767e791813f2adc8a1c2fc970f115ab3c30ce3fcfab8c99e6` | `ed4f5e3011738de767e791813f2adc8a1c2fc970f115ab3c30ce3fcfab8c99e6` | 608 |
| `UberOrderViewController.m` | `5d14235cbcc59a246d82e213f8824defdebe62ba8737ca54d7a554ff69253931` | `5d14235cbcc59a246d82e213f8824defdebe62ba8737ca54d7a554ff69253931` | 39801 |
| `VersionManagementViewController.h` | `5b262b3cec01fd6e030efc25672424f8a64b49d2c1ac7e3f54a32f1a959acbb2` | `5b262b3cec01fd6e030efc25672424f8a64b49d2c1ac7e3f54a32f1a959acbb2` | 955 |
| `VersionManagementViewController.m` | `68a33b786e2aea4999b07e37e4801c97e188be0b0dfc876da89e20403cff25ae` | `68a33b786e2aea4999b07e37e4801c97e188be0b0dfc876da89e20403cff25ae` | 68330 |
| `WeaponXGuardian.m` | `47db55dc74fe96ec3ae731843d7cbc8e0cbd9c647103a8cb797b7281e433f10b` | `47db55dc74fe96ec3ae731843d7cbc8e0cbd9c647103a8cb797b7281e433f10b` | 16859 |
| `WeaponXKeychainBridge.plist` | `e47d3b6c67ff941c9232d1fcf643bd94e81327cfd40244f1b5f38b99b918fe02` | `e47d3b6c67ff941c9232d1fcf643bd94e81327cfd40244f1b5f38b99b918fe02` | 386 |
| `WeaponXKeychainBridge/Tweak.m` | `e0733e04eb4915a4753fe59247b17acd5e8cb7f8fa5fcf0bb8dee94f908459aa` | `e0733e04eb4915a4753fe59247b17acd5e8cb7f8fa5fcf0bb8dee94f908459aa` | 21970 |
| `WeaponXMountDaemon/WeaponXDaemon.m` | `c9ba6d287f3743ce3aab7b76615f864d72f32404fa2d3ce85b2ebb0b3cf9dcb3` | `c9ba6d287f3743ce3aab7b76615f864d72f32404fa2d3ce85b2ebb0b3cf9dcb3` | 19900 |
| `WeaponXMountDaemon/WeaponXMountDaemon.m` | `30e9e71ba449199e2140e798d6e7b3e35e2f66710dc1bed2c70933af7af04a0f` | `30e9e71ba449199e2140e798d6e7b3e35e2f66710dc1bed2c70933af7af04a0f` | 11205 |
| `WebKit_Filtering.md` | `17e394e126e548a068785f0ab05a383726590e3f8e2ae99a285bc655c13a8c22` | `17e394e126e548a068785f0ab05a383726590e3f8e2ae99a285bc655c13a8c22` | 5499 |
| `com.hydra.weaponx.guardian.plist` | `713d7975fdedef0abb50e3207e34a9fbaedd241ec417174ebdd59fc2a6126f68` | `713d7975fdedef0abb50e3207e34a9fbaedd241ec417174ebdd59fc2a6126f68` | 1145 |
| `common/AppContainerUUIDManager.h` | `4ce1170d8f576bc9ae7da4a5a52faebf3f2a986ba66ad06561085270436ad9ac` | `4ce1170d8f576bc9ae7da4a5a52faebf3f2a986ba66ad06561085270436ad9ac` | 542 |
| `common/AppContainerUUIDManager.m` | `623df4a811358a3c897a1420c7f3fc6a72bcff1457540821a9e6db5524d05e55` | `623df4a811358a3c897a1420c7f3fc6a72bcff1457540821a9e6db5524d05e55` | 3559 |
| `common/AppGroupUUIDManager.h` | `dc28577f1bc5cade1942f4d9a646690fa20cf60544983238dfe0f2fff0c914af` | `dc28577f1bc5cade1942f4d9a646690fa20cf60544983238dfe0f2fff0c914af` | 406 |
| `common/AppGroupUUIDManager.m` | `e5597aecbda830fbc8373103ca68f4674a07231370a7a94b4d1ba78b16dc9355` | `e5597aecbda830fbc8373103ca68f4674a07231370a7a94b4d1ba78b16dc9355` | 3449 |
| `common/AppInstallUUIDManager.h` | `5af466057f85afaa59470dde8b576acc056f899246c207b79b91c0557c427c0c` | `5af466057f85afaa59470dde8b576acc056f899246c207b79b91c0557c427c0c` | 532 |
| `common/AppInstallUUIDManager.m` | `da9a3156ea08238c60a75c334bb328b13f81eeae876e996f22d8446cab8f66a3` | `da9a3156ea08238c60a75c334bb328b13f81eeae876e996f22d8446cab8f66a3` | 3539 |
| `common/BatteryManager.h` | `24eb8739f4d31c5b70d49393a14e3633cf56c1c5babb99bdab108fa5cb0a6430` | `24eb8739f4d31c5b70d49393a14e3633cf56c1c5babb99bdab108fa5cb0a6430` | 685 |
| `common/BatteryManager.m` | `77b12c45676efe1ce826a282ebe8bc5949ee5349d7405bf719ff6decebce5d26` | `77b12c45676efe1ce826a282ebe8bc5949ee5349d7405bf719ff6decebce5d26` | 13918 |
| `common/CarrierDB.h` | `b6696746582b7e687e4fe9ac3eb7dc20e3fdac74574b7e0834d6d08180ce4e32` | `b6696746582b7e687e4fe9ac3eb7dc20e3fdac74574b7e0834d6d08180ce4e32` | 1418 |
| `common/CarrierDB.m` | `a4ec03f2cceba3675db17b20024e867b8ffae39c55bba1b9591774c7f56b168e` | `a4ec03f2cceba3675db17b20024e867b8ffae39c55bba1b9591774c7f56b168e` | 12622 |
| `common/CoreDataUUIDManager.h` | `892e127ae63e1f47374dfb112f85932ae02ddc1ded28ec15f0e109bd7554fd1d` | `892e127ae63e1f47374dfb112f85932ae02ddc1ded28ec15f0e109bd7554fd1d` | 422 |
| `common/CoreDataUUIDManager.m` | `21f09a12da71e74b703bced4c7a9c4ef8fed1a2046824c8200510ee677045c85` | `21f09a12da71e74b703bced4c7a9c4ef8fed1a2046824c8200510ee677045c85` | 3450 |
| `common/DBDebugLogger.h` | `d3a600284f4f0bb5969eb39576b05432263e138fa1f0ab47ea393ee2d02fd714` | `d3a600284f4f0bb5969eb39576b05432263e138fa1f0ab47ea393ee2d02fd714` | 262 |
| `common/DBDebugLogger.m` | `c10cb0af16fe8e67187b6f9de6697a1e0f949dd6af03d8e69774eed946e92f42` | `c10cb0af16fe8e67187b6f9de6697a1e0f949dd6af03d8e69774eed946e92f42` | 2783 |
| `common/DeviceModelManager.h` | `fa94aa68e6de07ee7c7697fbfc88f30e929377a35b5083cf106af386a6a67865` | `fa94aa68e6de07ee7c7697fbfc88f30e929377a35b5083cf106af386a6a67865` | 1697 |
| `common/DeviceModelManager.m` | `2837317f930529299573cb37bd225a131f0cde10c01463c14631024dd3ffd5ab` | `2837317f930529299573cb37bd225a131f0cde10c01463c14631024dd3ffd5ab` | 37928 |
| `common/DeviceNameManager.h` | `0383dab0d4f5890e5f157abbdaf3c1a97b43373716768e1eb6699a80602c838c` | `0383dab0d4f5890e5f157abbdaf3c1a97b43373716768e1eb6699a80602c838c` | 385 |
| `common/DeviceNameManager.m` | `ce19316a6f3ee82166ce1d7867213bd108d1d5d1406b8ecd9fb0fe3ec4cba029` | `ce19316a6f3ee82166ce1d7867213bd108d1d5d1406b8ecd9fb0fe3ec4cba029` | 11474 |
| `common/DomainBlockingSettings.h` | `2892eb655c23d45ea40c8ee5e11815e941af7552b54cb573ad6953bfb01e1823` | `2892eb655c23d45ea40c8ee5e11815e941af7552b54cb573ad6953bfb01e1823` | 882 |
| `common/DomainBlockingSettings.m` | `b1e043159a2841c65795d3074cda14194b3b4a83a3fb5cd3652725b65abd132a` | `b1e043159a2841c65795d3074cda14194b3b4a83a3fb5cd3652725b65abd132a` | 12424 |
| `common/DyldCacheUUIDManager.h` | `984684afea3a133454c4518855930d546e5caea4fefacaf5b3eedfc78f062025` | `984684afea3a133454c4518855930d546e5caea4fefacaf5b3eedfc78f062025` | 411 |
| `common/DyldCacheUUIDManager.m` | `54f3a2087ef4f2f1d4116682733b19eb753f1e2ed1b0fbb8e75b8cb4cb208562` | `54f3a2087ef4f2f1d4116682733b19eb753f1e2ed1b0fbb8e75b8cb4cb208562` | 3458 |
| `common/IDFAManager.h` | `1dfa1d1f301419031727e3b1ec35dbb8cfb6ca1286e683663df6efe7bfcff1a1` | `1dfa1d1f301419031727e3b1ec35dbb8cfb6ca1286e683663df6efe7bfcff1a1` | 335 |
| `common/IDFAManager.m` | `7c0f5d758c886bc5bc38f9a800063c5bd223eeb745a823ac4a514a215c2c9a41` | `7c0f5d758c886bc5bc38f9a800063c5bd223eeb745a823ac4a514a215c2c9a41` | 2745 |
| `common/IDFVManager.h` | `0b4f9c2198d5ab9fe2b4935561f051efb120d7ba65d784fdafab42ef51751b29` | `0b4f9c2198d5ab9fe2b4935561f051efb120d7ba65d784fdafab42ef51751b29` | 335 |
| `common/IDFVManager.m` | `a1504d870759b9dcbeb2d3a65a4e3e2befe79b2af684702894c217bc34e0f7f6` | `a1504d870759b9dcbeb2d3a65a4e3e2befe79b2af684702894c217bc34e0f7f6` | 2712 |
| `common/IOSBuildDB.h` | `a5c31abe50dce78944fbb8229122d86c21445bd5b96cbab4ca5a9a9ff6160654` | `a5c31abe50dce78944fbb8229122d86c21445bd5b96cbab4ca5a9a9ff6160654` | 1092 |
| `common/IOSBuildDB.m` | `234aff3926a0b702f4d47d7b3df8b565d2f304c8035abb127a8c1480bba704e4` | `234aff3926a0b702f4d47d7b3df8b565d2f304c8035abb127a8c1480bba704e4` | 9567 |
| `common/IOSVersionInfo.h` | `6e34a51759ad38bd05669b69932a1119ca84cf284203ca3deefb2e0b1664d02a` | `6e34a51759ad38bd05669b69932a1119ca84cf284203ca3deefb2e0b1664d02a` | 592 |
| `common/IOSVersionInfo.m` | `d476ed2ca27e6d08721409a33695d6b42089b221dd778e929fe8c024198409c7` | `d476ed2ca27e6d08721409a33695d6b42089b221dd778e929fe8c024198409c7` | 15529 |
| `common/IPMonitorService.h` | `202a42c2804fa7d48c40c9ba44cc88bb7a45f584261c5afb51ff2b643a6b3317` | `202a42c2804fa7d48c40c9ba44cc88bb7a45f584261c5afb51ff2b643a6b3317` | 224 |
| `common/IPMonitorService.m` | `ded7e466921b9d4269488e5413ab2990622275259eb5c4954928ff09dcd83110` | `ded7e466921b9d4269488e5413ab2990622275259eb5c4954928ff09dcd83110` | 25567 |
| `common/IPStatusCacheManager.h` | `494c8e1e4aaeb1a4462fec95e56ed88249d72ea6f79fd5fffc501be83e39c887` | `494c8e1e4aaeb1a4462fec95e56ed88249d72ea6f79fd5fffc501be83e39c887` | 990 |
| `common/IPStatusCacheManager.m` | `0136ffd0b9c62a1f30f5f11543650b45f110bdd3a0eabb5bd084b70bf92acc39` | `0136ffd0b9c62a1f30f5f11543650b45f110bdd3a0eabb5bd084b70bf92acc39` | 12562 |
| `common/IPStatusViewController.h` | `24d983dca6be3c22410fbf51311a81a7a74027bfdd3e257d4c0b0b2eaa83eb73` | `24d983dca6be3c22410fbf51311a81a7a74027bfdd3e257d4c0b0b2eaa83eb73` | 271 |
| `common/IPStatusViewController.m` | `dd37fc4c0835422d88388dac46c02613eaad7d28cc3f20c3d0c63fb8221faa01` | `dd37fc4c0835422d88388dac46c02613eaad7d28cc3f20c3d0c63fb8221faa01` | 62749 |
| `common/IPhoneModelDB.h` | `93244605e5ea9088a44447686a27a22a39d132021b74b044212ef00e4633c449` | `93244605e5ea9088a44447686a27a22a39d132021b74b044212ef00e4633c449` | 885 |
| `common/IPhoneModelDB.m` | `e6a75c47d3aa47655cd0546237570b49f511c1d1c991f0fc850e65eae15cfd13` | `e6a75c47d3aa47655cd0546237570b49f511c1d1c991f0fc850e65eae15cfd13` | 6198 |
| `common/IdentifierManager.h` | `3c2c6c4a8c9ff7a39210229ee7c1d8f59e6bb2f6ac0358ea70fbd9e413f073da` | `3c2c6c4a8c9ff7a39210229ee7c1d8f59e6bb2f6ac0358ea70fbd9e413f073da` | 3082 |
| `common/IdentifierManager.m` | `f5fc51f24a50ce5457034326de4b5a5e64592d4dd2427b118e75137fe32fe48f` | `f5fc51f24a50ce5457034326de4b5a5e64592d4dd2427b118e75137fe32fe48f` | 160824 |
| `common/KeychainUUIDManager.h` | `e1354e95536dc3218b3afbc3f198aad582285b0037717ca0fb5515048d8eb626` | `e1354e95536dc3218b3afbc3f198aad582285b0037717ca0fb5515048d8eb626` | 405 |
| `common/KeychainUUIDManager.m` | `954bc45263985727851347397300ea31ff908e0464a5cf4efdf29a93df633e02` | `954bc45263985727851347397300ea31ff908e0464a5cf4efdf29a93df633e02` | 3479 |
| `common/LocationSpoofingManager.h` | `fcdcc9cbd2ef2edecd9461b0df81376468fd525cf4d2bf361a931d556cb8ffa3` | `fcdcc9cbd2ef2edecd9461b0df81376468fd525cf4d2bf361a931d556cb8ffa3` | 3202 |
| `common/LocationSpoofingManager.m` | `12d2d700334d36bb49abd5231155c85f49e42db1ea9abfc374750f06d3760581` | `12d2d700334d36bb49abd5231155c85f49e42db1ea9abfc374750f06d3760581` | 65282 |
| `common/NetworkManager.h` | `2f05d075712b6ab037e94d10fe885a4fb2277cbf97ed8e56ae2831398c37cdea` | `2f05d075712b6ab037e94d10fe885a4fb2277cbf97ed8e56ae2831398c37cdea` | 1065 |
| `common/NetworkManager.m` | `d991dc30a5a172f0ac5497a95ee8407f7fc4062b96582415abf7b71cacad7af8` | `d991dc30a5a172f0ac5497a95ee8407f7fc4062b96582415abf7b71cacad7af8` | 17926 |
| `common/PXPaths.h` | `106bdf4dd1a58c34af7edb804515d7751807897834fdd798d99cd4ec2f853f9d` | `106bdf4dd1a58c34af7edb804515d7751807897834fdd798d99cd4ec2f853f9d` | 616 |
| `common/PXPaths.m` | `3577ba31ef5e8c8282657b06b198606b54ccebbdcf30075a2b1ec4703d810de9` | `3577ba31ef5e8c8282657b06b198606b54ccebbdcf30075a2b1ec4703d810de9` | 2283 |
| `common/PXProcessKiller.h` | `a5c0f8a9f821c5841d68495c911db230dc1225bb79468498df1a0fe9f1a405e2` | `a5c0f8a9f821c5841d68495c911db230dc1225bb79468498df1a0fe9f1a405e2` | 554 |
| `common/PXProcessKiller.m` | `e2a1281cbd11b2a67783136fe68c73d802e96458367a7b3e95f95995bafb72b6` | `e2a1281cbd11b2a67783136fe68c73d802e96458367a7b3e95f95995bafb72b6` | 4565 |
| `common/PassThroughWindow.h` | `aea14d36dea1c40ccf7d369cf5354f56e43bc99076839ac7e7d5792d71d16d11` | `aea14d36dea1c40ccf7d369cf5354f56e43bc99076839ac7e7d5792d71d16d11` | 75 |
| `common/PassThroughWindow.m` | `c23d77e605a331ae040b236faa01d6819fd28f22e01bbe1532fc2f762f537c9c` | `c23d77e605a331ae040b236faa01d6819fd28f22e01bbe1532fc2f762f537c9c` | 486 |
| `common/PasteboardUUIDManager.h` | `5af2e4a7a7584f794c98e46848848b06caac05ce889d92eb39a9a7aeaa64c5af` | `5af2e4a7a7584f794c98e46848848b06caac05ce889d92eb39a9a7aeaa64c5af` | 415 |
| `common/PasteboardUUIDManager.m` | `9be2bf8148188a4f0c063c0691f9f1a1c8139e7fea26e88539ababcf06718078` | `9be2bf8148188a4f0c063c0691f9f1a1c8139e7fea26e88539ababcf06718078` | 3466 |
| `common/ProfileIndicatorView.h` | `a4d214bd120b31126f0216cd032b4022fa58152393421e6006d32ee903567f7f` | `a4d214bd120b31126f0216cd032b4022fa58152393421e6006d32ee903567f7f` | 174 |
| `common/ProfileIndicatorView.m` | `278783df004305078ff12a2bb747ce544b57b4be5f8bc410139cb739e854c1e0` | `278783df004305078ff12a2bb747ce544b57b4be5f8bc410139cb739e854c1e0` | 56659 |
| `common/ProfileManager.h` | `f17f634cae35967d04216783a87b386d537fd038d4ee8945982a527a768581e8` | `f17f634cae35967d04216783a87b386d537fd038d4ee8945982a527a768581e8` | 2322 |
| `common/ProfileManager.m` | `cb9c6d7beb8bf935cd987f24fb465d90a8a0e61c3905de99ca4a48ba566a4178` | `cb9c6d7beb8bf935cd987f24fb465d90a8a0e61c3905de99ca4a48ba566a4178` | 72206 |
| `common/ProjectXLogging.h` | `ddcc64ac4ab1dcf7130f3b3068e38ac83cbfa7119ed2696fc9c22ac49925676d` | `ddcc64ac4ab1dcf7130f3b3068e38ac83cbfa7119ed2696fc9c22ac49925676d` | 460 |
| `common/ProjectXLogging.m` | `447ddd5d9cef8a552bd56ba6e2f3589b70e7185ae4168aaf424a69dd85cecdff` | `447ddd5d9cef8a552bd56ba6e2f3589b70e7185ae4168aaf424a69dd85cecdff` | 4712 |
| `common/ScoreMeterView.h` | `0e9fc5d62252750ce6432032d275c920321b8314eb1aa95d8e036ace220ac1b4` | `0e9fc5d62252750ce6432032d275c920321b8314eb1aa95d8e036ace220ac1b4` | 200 |
| `common/ScoreMeterView.m` | `415d41c0765f93d2f33b50912d746f3efd684b66b625d6d9b9a7f59d9a8272a3` | `415d41c0765f93d2f33b50912d746f3efd684b66b625d6d9b9a7f59d9a8272a3` | 2650 |
| `common/SerialNumberManager.h` | `e93ad6cbfe58c9edb2d44b5c620f4f03d84b71886de47a2933139f3334f07a49` | `e93ad6cbfe58c9edb2d44b5c620f4f03d84b71886de47a2933139f3334f07a49` | 486 |
| `common/SerialNumberManager.m` | `6bc5049f5a7bda8023f2d1ba743f703c964dba99a49da9969c0484a0fe38389b` | `6bc5049f5a7bda8023f2d1ba743f703c964dba99a49da9969c0484a0fe38389b` | 6005 |
| `common/StorageManager.h` | `3dac3c91e1340ecd4a03f193a1efc5484da0cfee028b8f0c7eec01146c1c3659` | `3dac3c91e1340ecd4a03f193a1efc5484da0cfee028b8f0c7eec01146c1c3659` | 3350 |
| `common/StorageManager.m` | `e1c43bdcc633d5d15c3d9680f65ffa234a14158ca462ed66f6a1cb62eb096c8c` | `e1c43bdcc633d5d15c3d9680f65ffa234a14158ca462ed66f6a1cb62eb096c8c` | 9610 |
| `common/SystemUUIDManager.h` | `f4e4413cb563255a9b4fd9a49ea827662da0a698925e5d5e921849ba52f3f646` | `f4e4413cb563255a9b4fd9a49ea827662da0a698925e5d5e921849ba52f3f646` | 387 |
| `common/SystemUUIDManager.m` | `bcf62bc2190c5236cf9fbbf4a6768f922c4ff2a760fdf6c7c02bb815088aee80` | `bcf62bc2190c5236cf9fbbf4a6768f922c4ff2a760fdf6c7c02bb815088aee80` | 3422 |
| `common/UIButton+SafeConfiguration.h` | `6591286ab29bfc5cc33ae44cbed0d0afc8b0117e65673c49599d83a945679172` | `6591286ab29bfc5cc33ae44cbed0d0afc8b0117e65673c49599d83a945679172` | 984 |
| `common/UIButton+SafeConfiguration.m` | `0d85824389132f835505bd23dedcfe0730f9477ed79bc4e51e1f0937cf90e755` | `0d85824389132f835505bd23dedcfe0730f9477ed79bc4e51e1f0937cf90e755` | 1672 |
| `common/UIButtonCompat.h` | `beb3a675c2731563de824d09ca899392c91bb776e6861ae986f497189b41cefe` | `beb3a675c2731563de824d09ca899392c91bb776e6861ae986f497189b41cefe` | 1581 |
| `common/UIButtonCompat.m` | `3077e591bde05e4a7bf8a126b7e946533ffd0d7f56a6e10175f562c6ab8efd68` | `3077e591bde05e4a7bf8a126b7e946533ffd0d7f56a6e10175f562c6ab8efd68` | 5833 |
| `common/UptimeManager.h` | `2bc2b60a4d351134bfea13c4d0a9c80d0da2ef01fa0c8b69226a67a5fcdefa60` | `2bc2b60a4d351134bfea13c4d0a9c80d0da2ef01fa0c8b69226a67a5fcdefa60` | 1039 |
| `common/UptimeManager.m` | `1772f1d6c6a4ac8fe67690744be083f90806fa5a53e3fd327b555cafbd429320` | `1772f1d6c6a4ac8fe67690744be083f90806fa5a53e3fd327b555cafbd429320` | 18221 |
| `common/UserDefaultsUUIDManager.h` | `3636875e5fbf661308ac2c2ee306a1cc615589f37c9e76dfb9f73a207d603806` | `3636875e5fbf661308ac2c2ee306a1cc615589f37c9e76dfb9f73a207d603806` | 425 |
| `common/UserDefaultsUUIDManager.m` | `be8ebdb9af1980e8c6a2ad79f31610dc44fdfe6d7395682efad1f0bb33e12f48` | `be8ebdb9af1980e8c6a2ad79f31610dc44fdfe6d7395682efad1f0bb33e12f48` | 3484 |
| `common/VersionCompare.h` | `d839282397f82831f9ea163f40f131744021348508f8b51fcfee588613739094` | `d839282397f82831f9ea163f40f131744021348508f8b51fcfee588613739094` | 519 |
| `common/VersionCompare.m` | `ea72d0f06cbd476ed49c0f13f44bb985f1ca8c2bb3d8d16c82e5c292f8df23a4` | `ea72d0f06cbd476ed49c0f13f44bb985f1ca8c2bb3d8d16c82e5c292f8df23a4` | 1936 |
| `common/WiFiManager.h` | `dcadd6fea432ad255f5a509253d9f6ebb353ab714dd1adc6e20e327b6015fbdc` | `dcadd6fea432ad255f5a509253d9f6ebb353ab714dd1adc6e20e327b6015fbdc` | 664 |
| `common/WiFiManager.m` | `dfc32e8d70c23b0dd95de81c35697e0e1816d3358b4e77228b85430d2a4b98e3` | `dfc32e8d70c23b0dd95de81c35697e0e1816d3358b4e77228b85430d2a4b98e3` | 26544 |
| `control` | `fcc89e22298b1a2eefa691d09462d1ae6bb86b805deb43ec71d40bce6e33a4ea` | `fcc89e22298b1a2eefa691d09462d1ae6bb86b805deb43ec71d40bce6e33a4ea` | 469 |
| `data/carrier_db.json` | `003d4bc3cfb44f7af45ba59e65afc9305957f0ba57a7b42db44a114402192e1b` | `003d4bc3cfb44f7af45ba59e65afc9305957f0ba57a7b42db44a114402192e1b` | 17230 |
| `ent.plist` | `ad383179c6f8a88b875aa34ae8a1fb85496ad002512210272a85cc81145c0164` | `ad383179c6f8a88b875aa34ae8a1fb85496ad002512210272a85cc81145c0164` | 2881 |
| `iOSVersionManager.h` | `91b56e6517f142f5bff9560bf0ad9c111d6a150bafbe57756b9c05e41878948c` | `91b56e6517f142f5bff9560bf0ad9c111d6a150bafbe57756b9c05e41878948c` | 404 |
| `include/.DS_Store` | `d1b132f85d7cbdb006d39402f5e3ab335ddfcb296b2090c6676887034c73894b` | `d1b132f85d7cbdb006d39402f5e3ab335ddfcb296b2090c6676887034c73894b` | 6148 |
| `include/HookKit` | `27fc5a751717503f49497e1a9e6b5a08347bb83c55478387f073e96fc8e82737` | `27fc5a751717503f49497e1a9e6b5a08347bb83c55478387f073e96fc8e82737` | 38 |
| `include/ellekit/ellekit.h` | `e3b645ef988671709a238480808415ca7601c63b8dcc947a3619fbdbdc593c13` | `e3b645ef988671709a238480808415ca7601c63b8dcc947a3619fbdbdc593c13` | 5050 |
| `include/substrate.h` | `d51adfd695c82181b0145db7129dc320ea45a2e1ce19028a0b16fd9b1d3563d7` | `d51adfd695c82181b0145db7129dc320ea45a2e1ce19028a0b16fd9b1d3563d7` | 44 |
| `keychain_base_ent.plist` | `8661cc558cb294239068ce2c24958dc2e717e80998c4f342ad1a9c463fb45496` | `8661cc558cb294239068ce2c24958dc2e717e80998c4f342ad1a9c463fb45496` | 912 |
| `layout/Library/libSandy/projectx_filesystem_access.plist` | `6d8f04e9463c9fa8cf096ba4bf25dd312a0bec29cb605d9a93c48e8f29837a49` | `6d8f04e9463c9fa8cf096ba4bf25dd312a0bec29cb605d9a93c48e8f29837a49` | 2557 |
| `location.png` | `28129305b1bf9bef807b3473f85fc507f1ee21186168e4513b1c875ec94eb889` | `28129305b1bf9bef807b3473f85fc507f1ee21186168e4513b1c875ec94eb889` | 6132 |
| `main.m` | `7723b95eef99fdc9b8e949daf135cb03e7c8eaad1c000b4db9361eccbfc0f0da` | `7723b95eef99fdc9b8e949daf135cb03e7c8eaad1c000b4db9361eccbfc0f0da` | 23462 |
| `postinst` | `a0143e7e9e08efca6dd430098185cc816cfdf7c8bb025d504430a74d4b2917e7` | `a0143e7e9e08efca6dd430098185cc816cfdf7c8bb025d504430a74d4b2917e7` | 6118 |
| `scripts/audit_native_hooks.sh` | `9216ef3fcab69bb66f50d7d4b70296719d615a778005dd24aa6babf7d8d95a99` | `9216ef3fcab69bb66f50d7d4b70296719d615a778005dd24aa6babf7d8d95a99` | 4225 |
| `scripts/keychain_backup.sh` | `b3f05517ab230b9f37acfefe4c81568e3f88268c5e110653a50b3d30bd9437ae` | `b3f05517ab230b9f37acfefe4c81568e3f88268c5e110653a50b3d30bd9437ae` | 32096 |
| `scripts/setup_altlist.sh` | `9921781055e69f08bc6cce043c64f3e59eeabb65fff6e240f4efb12e95aeab7a` | `9921781055e69f08bc6cce043c64f3e59eeabb65fff6e240f4efb12e95aeab7a` | 1567 |
| `setup_app.sh` | `dbbf9afa6efc1be0ad11b2bf3f61d466f827d58ff9e59bb9872cf1897ae7791e` | `dbbf9afa6efc1be0ad11b2bf3f61d466f827d58ff9e59bb9872cf1897ae7791e` | 1679 |
| `setup_dependencies.sh` | `12fe51bafa3c13ddc8b53d82c8fc0384be6eee43bc34871bac1722bcdf2a9b4b` | `12fe51bafa3c13ddc8b53d82c8fc0384be6eee43bc34871bac1722bcdf2a9b4b` | 524 |
| `weaponx-debug.sh` | `720dfc3a974712d614c30938a0b40e8fb783eedd96aade3bf6f2fa178ceff024` | `720dfc3a974712d614c30938a0b40e8fb783eedd96aade3bf6f2fa178ceff024` | 6254 |
## Authorized production artifact hashes
| File | SHA-256 | Bytes | Lines |
|---|---|---:|---:|
| `PXBackupDirectoryDiscovery.h` | `da0b54991b39159de122169227f28827f6fde2375c1fe52ff9c47902143d2df2` | 1708 | 41 |
| `PXBackupDirectoryDiscovery.m` | `f7380363790e5fbc896f64b3b9c2b325361ec26745196c2874cc1b1d153448c5` | 38228 | 792 |
| `PXBackupStaleWorkspaceCleanup.h` | `82cdc1e356907c75e9e04b39de6ff81809bd50cb0fd265d2683d865444cba76d` | 2265 | 51 |
| `PXBackupStaleWorkspaceCleanup.m` | `14c50d4f6b85125e07bdb96a9bcad13a8fdaccd4857f9d3c76a0291a38865f74` | 77336 | 1801 |
| `AppDataBackupManager.m` | `d6a302c90ab988a2c9b27c36fa664bc219082c6175f631942426b5fb91d2191e` | 221835 | 4194 |
## Full authorized production diff
```diff
--- /dev/null
+++ b/PXBackupDirectoryDiscovery.h
@@ -0,0 +1,41 @@
+#import <Foundation/Foundation.h>
+
+NS_ASSUME_NONNULL_BEGIN
+
+FOUNDATION_EXPORT NSErrorDomain const PXBackupDirectoryDiscoveryErrorDomain;
+FOUNDATION_EXPORT NSString * const PXBackupDirectoryDiscoveryErrorFieldPathKey;
+
+typedef NS_ERROR_ENUM(PXBackupDirectoryDiscoveryErrorDomain,
+                      PXBackupDirectoryDiscoveryErrorCode) {
+    PXBackupDirectoryDiscoveryErrorInvalidInput = 1,
+    PXBackupDirectoryDiscoveryErrorLimitExceeded = 2,
+    PXBackupDirectoryDiscoveryErrorRootInspectionFailed = 3,
+    PXBackupDirectoryDiscoveryErrorBundleDirectoryInvalid = 4,
+    PXBackupDirectoryDiscoveryErrorTraversalFailed = 5,
+    PXBackupDirectoryDiscoveryErrorEntryChanged = 6,
+    PXBackupDirectoryDiscoveryErrorFilesystemChanged = 7,
+    PXBackupDirectoryDiscoveryErrorManifestOpenFailed = 8,
+    PXBackupDirectoryDiscoveryErrorManifestReadFailed = 9,
+    PXBackupDirectoryDiscoveryErrorManifestParseFailed = 10,
+    PXBackupDirectoryDiscoveryErrorManifestInvalid = 11,
+    PXBackupDirectoryDiscoveryErrorUnsupportedManifestVersion = 12,
+    PXBackupDirectoryDiscoveryErrorBundleIdentifierMismatch = 13,
+    PXBackupDirectoryDiscoveryErrorPublishedNameMismatch = 14,
+    PXBackupDirectoryDiscoveryErrorDuplicateBackup = 15,
+    PXBackupDirectoryDiscoveryErrorInternalInvariantFailed = 16,
+};
+
+__attribute__((objc_subclassing_restricted))
+@interface PXBackupDirectoryDiscovery : NSObject
+
++ (nullable NSArray<NSString *> *)discoverBackupDirectoriesAtBackupRoots:
+    (NSArray<NSString *> *)backupRoots
+    bundleIdentifier:(NSString *)bundleIdentifier
+    error:(NSError * _Nullable * _Nullable)error;
+
+- (instancetype)init NS_UNAVAILABLE;
++ (instancetype)new NS_UNAVAILABLE;
+
+@end
+
+NS_ASSUME_NONNULL_END
--- /dev/null
+++ b/PXBackupDirectoryDiscovery.m
@@ -0,0 +1,792 @@
+#import "PXBackupDirectoryDiscovery.h"
+#import "PXBackupManifestValidator.h"
+
+#import <CoreFoundation/CoreFoundation.h>
+
+#include <dirent.h>
+#include <errno.h>
+#include <fcntl.h>
+#include <stdint.h>
+#include <stdlib.h>
+#include <string.h>
+#include <sys/stat.h>
+#include <sys/types.h>
+#include <unistd.h>
+
+NSErrorDomain const PXBackupDirectoryDiscoveryErrorDomain =
+    @"com.hydra.projectx.backup-directory-discovery";
+NSString * const PXBackupDirectoryDiscoveryErrorFieldPathKey = @"fieldPath";
+
+static NSString * const PXDiscoveryInputField = @"$.discovery.input";
+static NSString * const PXDiscoveryRootField = @"$.discovery.root";
+static NSString * const PXDiscoveryBundleField = @"$.discovery.bundle";
+static NSString * const PXDiscoveryTraversalField = @"$.discovery.traversal";
+
+static const NSUInteger PXDiscoveryMaximumRoots = 8U;
+static const NSUInteger PXDiscoveryMaximumRootPathBytes = 4096U;
+static const NSUInteger PXDiscoveryMaximumComponentBytes = 255U;
+static const NSUInteger PXDiscoveryMaximumEntriesPerBundleRoot = 16384U;
+static const NSUInteger PXDiscoveryMaximumAggregateEntries = 32768U;
+static const unsigned long long PXDiscoveryMaximumManifestBytes =
+    128ULL * 1024ULL * 1024ULL;
+static const size_t PXDiscoveryReadBufferBytes = 64U * 1024U;
+static const NSUInteger PXDiscoveryMaximumAcceptedBackups = 4096U;
+
+static const char PXDiscoveryManifestFileName[] = "manifest.plist";
+static const char PXDiscoveryPartialPrefix[] = ".weaponx-backup-partial-";
+static const char PXDiscoveryQuarantinePrefix[] = ".weaponx-cleanup-quarantine-";
+static const char PXDiscoveryLockFileName[] = ".weaponx-backup.lock";
+
+#if defined(__APPLE__)
+#define PX_DISCOVERY_MTIME_SEC(value) ((value).st_mtimespec.tv_sec)
+#define PX_DISCOVERY_MTIME_NSEC(value) ((value).st_mtimespec.tv_nsec)
+#define PX_DISCOVERY_CTIME_SEC(value) ((value).st_ctimespec.tv_sec)
+#define PX_DISCOVERY_CTIME_NSEC(value) ((value).st_ctimespec.tv_nsec)
+#else
+#define PX_DISCOVERY_MTIME_SEC(value) ((value).st_mtim.tv_sec)
+#define PX_DISCOVERY_MTIME_NSEC(value) ((value).st_mtim.tv_nsec)
+#define PX_DISCOVERY_CTIME_SEC(value) ((value).st_ctim.tv_sec)
+#define PX_DISCOVERY_CTIME_NSEC(value) ((value).st_ctim.tv_nsec)
+#endif
+
+static void PXDiscoverySetError(NSError **error,
+                                PXBackupDirectoryDiscoveryErrorCode code,
+                                NSString *field,
+                                NSString *description) {
+    if (!error) return;
+    *error = [NSError errorWithDomain:PXBackupDirectoryDiscoveryErrorDomain
+                                 code:code
+                             userInfo:@{
+                                 NSLocalizedDescriptionKey: description,
+                                 PXBackupDirectoryDiscoveryErrorFieldPathKey: field,
+                             }];
+}
+
+static BOOL PXDiscoveryDescriptorHasCloseOnExec(int descriptor) {
+    if (descriptor < 0) return NO;
+    int flags = -1;
+    do {
+        flags = fcntl(descriptor, F_GETFD);
+    } while (flags < 0 && errno == EINTR);
+    return flags >= 0 && (flags & FD_CLOEXEC) != 0;
+}
+
+static int PXDiscoveryDuplicateDescriptor(int descriptor) {
+    if (descriptor < 0) return -1;
+    int duplicate = -1;
+    do {
+        duplicate = fcntl(descriptor, F_DUPFD_CLOEXEC, 0);
+    } while (duplicate < 0 && errno == EINTR);
+    if (duplicate < 0 || !PXDiscoveryDescriptorHasCloseOnExec(duplicate)) {
+        if (duplicate >= 0) close(duplicate);
+        return -1;
+    }
+    return duplicate;
+}
+
+static BOOL PXDiscoveryStatIdentityMatches(const struct stat *left,
+                                           const struct stat *right) {
+    return left && right &&
+        left->st_dev == right->st_dev &&
+        left->st_ino == right->st_ino &&
+        ((left->st_mode & S_IFMT) == (right->st_mode & S_IFMT));
+}
+
+static BOOL PXDiscoveryStableMetadataMatches(const struct stat *left,
+                                             const struct stat *right) {
+    return PXDiscoveryStatIdentityMatches(left, right) &&
+        left->st_mode == right->st_mode &&
+        left->st_nlink == right->st_nlink &&
+        left->st_size == right->st_size &&
+        PX_DISCOVERY_MTIME_SEC(*left) == PX_DISCOVERY_MTIME_SEC(*right) &&
+        PX_DISCOVERY_MTIME_NSEC(*left) == PX_DISCOVERY_MTIME_NSEC(*right) &&
+        PX_DISCOVERY_CTIME_SEC(*left) == PX_DISCOVERY_CTIME_SEC(*right) &&
+        PX_DISCOVERY_CTIME_NSEC(*left) == PX_DISCOVERY_CTIME_NSEC(*right);
+}
+
+static BOOL PXDiscoveryStringContainsNUL(NSString *value) {
+    if (![value isKindOfClass:[NSString class]]) return YES;
+    for (NSUInteger index = 0; index < value.length; index++) {
+        if ([value characterAtIndex:index] == 0) return YES;
+    }
+    return NO;
+}
+
+static BOOL PXDiscoveryValidateLosslessString(NSString *value,
+                                              NSUInteger maximumBytes,
+                                              BOOL requireAbsolute,
+                                              BOOL requireComponent,
+                                              NSData **dataOut) {
+    if (dataOut) *dataOut = nil;
+    if (![value isKindOfClass:[NSString class]] || value.length == 0 ||
+        PXDiscoveryStringContainsNUL(value)) return NO;
+    if (requireAbsolute && ![value hasPrefix:@"/"]) return NO;
+    if (requireComponent && ([value isEqualToString:@"."] ||
+                             [value isEqualToString:@".."])) return NO;
+    if (requireComponent) {
+        for (NSUInteger index = 0; index < value.length; index++) {
+            unichar character = [value characterAtIndex:index];
+            if (character == '/' || character == '\\' ||
+                character < 0x20 || character == 0x7f || character == 0) {
+                return NO;
+            }
+        }
+    }
+    NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding
+                       allowLossyConversion:NO];
+    if (![data isKindOfClass:[NSData class]] ||
+        data.length == 0 || data.length > maximumBytes) return NO;
+    NSString *roundTrip = [[NSString alloc] initWithData:data
+                                                encoding:NSUTF8StringEncoding];
+    if (![roundTrip isKindOfClass:[NSString class]] ||
+        ![roundTrip isEqualToString:value]) return NO;
+    if (dataOut) *dataOut = data;
+    return YES;
+}
+
+static char *PXDiscoveryCopyCString(NSData *data) {
+    if (![data isKindOfClass:[NSData class]] || data.length == 0 ||
+        data.length > SIZE_MAX - 1U) return NULL;
+    char *bytes = malloc(data.length + 1U);
+    if (!bytes) return NULL;
+    memcpy(bytes, data.bytes, data.length);
+    bytes[data.length] = '\0';
+    return bytes;
+}
+
+static BOOL PXDiscoveryValidateRawComponent(const char *name,
+                                            NSString **stringOut) {
+    if (stringOut) *stringOut = nil;
+    if (!name) return NO;
+    size_t length = 0;
+    while (length <= PXDiscoveryMaximumComponentBytes && name[length] != '\0') {
+        length += 1U;
+    }
+    if (length == 0 || length > PXDiscoveryMaximumComponentBytes ||
+        (length == 1U && name[0] == '.') ||
+        (length == 2U && name[0] == '.' && name[1] == '.')) return NO;
+    for (size_t index = 0; index < length; index++) {
+        unsigned char byte = (unsigned char)name[index];
+        if (byte == '/' || byte == '\\' || byte < 0x20 || byte == 0x7f) return NO;
+    }
+    NSString *value = [[NSString alloc] initWithBytes:name
+                                                length:length
+                                              encoding:NSUTF8StringEncoding];
+    if (![value isKindOfClass:[NSString class]]) return NO;
+    NSData *roundTrip = [value dataUsingEncoding:NSUTF8StringEncoding
+                            allowLossyConversion:NO];
+    if (![roundTrip isKindOfClass:[NSData class]] ||
+        roundTrip.length != length ||
+        memcmp(roundTrip.bytes, name, length) != 0) return NO;
+    if (stringOut) *stringOut = value;
+    return YES;
+}
+
+static BOOL PXDiscoveryIsReservedOrHidden(const char *name) {
+    if (!name || name[0] == '\0' || name[0] == '.') return YES;
+    return strcmp(name, PXDiscoveryLockFileName) == 0 ||
+        strncmp(name,
+                PXDiscoveryPartialPrefix,
+                sizeof(PXDiscoveryPartialPrefix) - 1U) == 0 ||
+        strncmp(name,
+                PXDiscoveryQuarantinePrefix,
+                sizeof(PXDiscoveryQuarantinePrefix) - 1U) == 0;
+}
+
+static NSString *PXDiscoveryAppendComponent(NSString *base,
+                                            NSString *component) {
+    if (![base isKindOfClass:[NSString class]] ||
+        ![component isKindOfClass:[NSString class]]) return nil;
+    return [base hasSuffix:@"/"]
+        ? [base stringByAppendingString:component]
+        : [base stringByAppendingFormat:@"/%@", component];
+}
+
+static NSArray<NSString *> *PXDiscoveryCopySortedEntryNames(
+    int directoryDescriptor,
+    NSUInteger maximumEntries,
+    NSUInteger *aggregateCount,
+    NSError **error) {
+    if (directoryDescriptor < 0 || !aggregateCount) {
+        PXDiscoverySetError(error,
+                            PXBackupDirectoryDiscoveryErrorInvalidInput,
+                            PXDiscoveryTraversalField,
+                            @"The directory enumeration inputs are invalid");
+        return nil;
+    }
+    int duplicate = PXDiscoveryDuplicateDescriptor(directoryDescriptor);
+    if (duplicate < 0) {
+        PXDiscoverySetError(error,
+                            PXBackupDirectoryDiscoveryErrorTraversalFailed,
+                            PXDiscoveryTraversalField,
+                            @"The backup directory could not be enumerated safely");
+        return nil;
+    }
+    DIR *directory = fdopendir(duplicate);
+    if (!directory) {
+        close(duplicate);
+        PXDiscoverySetError(error,
+                            PXBackupDirectoryDiscoveryErrorTraversalFailed,
+                            PXDiscoveryTraversalField,
+                            @"The backup directory enumeration could not be opened");
+        return nil;
+    }
+    NSMutableArray<NSString *> *names = [NSMutableArray array];
+    BOOL succeeded = YES;
+    for (;;) {
+        errno = 0;
+        struct dirent *entry = readdir(directory);
+        if (!entry) {
+            if (errno != 0) succeeded = NO;
+            break;
+        }
+        if ((entry->d_name[0] == '.' && entry->d_name[1] == '\0') ||
+            (entry->d_name[0] == '.' && entry->d_name[1] == '.' &&
+             entry->d_name[2] == '\0')) continue;
+        if (names.count >= maximumEntries ||
+            *aggregateCount >= PXDiscoveryMaximumAggregateEntries ||
+            *aggregateCount == NSUIntegerMax) {
+            succeeded = NO;
+            PXDiscoverySetError(error,
+                                PXBackupDirectoryDiscoveryErrorLimitExceeded,
+                                PXDiscoveryTraversalField,
+                                @"The backup discovery entry limit was exceeded");
+            break;
+        }
+        NSString *name = nil;
+        if (!PXDiscoveryValidateRawComponent(entry->d_name, &name)) continue;
+        [names addObject:name];
+        *aggregateCount += 1U;
+    }
+    closedir(directory);
+    if (!succeeded) {
+        if (error && !*error) {
+            PXDiscoverySetError(error,
+                                PXBackupDirectoryDiscoveryErrorTraversalFailed,
+                                PXDiscoveryTraversalField,
+                                @"The backup directory enumeration failed");
+        }
+        return nil;
+    }
+    [names sortUsingComparator:^NSComparisonResult(NSString *left,
+                                                    NSString *right) {
+        NSData *leftData = [left dataUsingEncoding:NSUTF8StringEncoding];
+        NSData *rightData = [right dataUsingEncoding:NSUTF8StringEncoding];
+        NSUInteger common = MIN(leftData.length, rightData.length);
+        int comparison = common == 0 ? 0 :
+            memcmp(leftData.bytes, rightData.bytes, common);
+        if (comparison < 0) return NSOrderedAscending;
+        if (comparison > 0) return NSOrderedDescending;
+        if (leftData.length < rightData.length) return NSOrderedAscending;
+        if (leftData.length > rightData.length) return NSOrderedDescending;
+        return NSOrderedSame;
+    }];
+    return [names copy];
+}
+
+static BOOL PXDiscoveryReadUnsignedIntegral(id value,
+                                            unsigned long long *numberOut) {
+    if (![value isKindOfClass:[NSNumber class]] ||
+        CFGetTypeID((__bridge CFTypeRef)value) != CFNumberGetTypeID()) return NO;
+    const char *type = [(NSNumber *)value objCType];
+    if (!type || !type[0]) return NO;
+    unsigned long long result = 0;
+    switch (type[0]) {
+        case 'C': case 'S': case 'I': case 'L': case 'Q':
+            result = [(NSNumber *)value unsignedLongLongValue];
+            break;
+        case 'c': case 's': case 'i': case 'l': case 'q': {
+            long long signedValue = [(NSNumber *)value longLongValue];
+            if (signedValue < 0) return NO;
+            result = (unsigned long long)signedValue;
+            break;
+        }
+        default:
+            return NO;
+    }
+    if (numberOut) *numberOut = result;
+    return YES;
+}
+
+static BOOL PXDiscoveryReadString(id value, NSString **stringOut) {
+    if (stringOut) *stringOut = nil;
+    if (![value isKindOfClass:[NSString class]]) return NO;
+    if (stringOut) *stringOut = (NSString *)value;
+    return YES;
+}
+
+static BOOL PXDiscoveryTimestampIsCanonical(NSString *timestamp) {
+    NSData *ascii = [timestamp dataUsingEncoding:NSASCIIStringEncoding
+                            allowLossyConversion:NO];
+    if (![ascii isKindOfClass:[NSData class]] || ascii.length != 15U) return NO;
+    const unsigned char *bytes = ascii.bytes;
+    for (NSUInteger index = 0; index < 15U; index++) {
+        if (index == 8U) {
+            if (bytes[index] != '-') return NO;
+        } else if (bytes[index] < '0' || bytes[index] > '9') {
+            return NO;
+        }
+    }
+    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
+    formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
+    formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
+    formatter.dateFormat = @"yyyyMMdd-HHmmss";
+    formatter.lenient = NO;
+    NSDate *date = [formatter dateFromString:timestamp];
+    return date && [[formatter stringFromDate:date] isEqualToString:timestamp];
+}
+
+static BOOL PXDiscoveryBackupIdentifierIsCanonical(NSString *backupIdentifier) {
+    NSData *ascii = [backupIdentifier dataUsingEncoding:NSASCIIStringEncoding
+                                   allowLossyConversion:NO];
+    if (![ascii isKindOfClass:[NSData class]] || ascii.length != 36U) return NO;
+    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:backupIdentifier];
+    return uuid && [[uuid.UUIDString lowercaseString] isEqualToString:backupIdentifier];
+}
+
+static NSData *PXDiscoveryReadManifestData(int candidateDescriptor,
+                                          const struct stat *candidateIdentity,
+                                          struct stat *manifestIdentityOut) {
+    int manifestDescriptor = -1;
+    NSMutableData *data = nil;
+    unsigned char *buffer = NULL;
+    NSData *result = nil;
+    struct stat namespaceBefore;
+    struct stat descriptorBefore;
+    struct stat descriptorAfter;
+    struct stat namespaceAfter;
+    if (candidateDescriptor < 0 || !candidateIdentity || !manifestIdentityOut) goto cleanup;
+    if (fstatat(candidateDescriptor,
+                PXDiscoveryManifestFileName,
+                &namespaceBefore,
+                AT_SYMLINK_NOFOLLOW) != 0 ||
+        !S_ISREG(namespaceBefore.st_mode) ||
+        namespaceBefore.st_nlink != 1 ||
+        (namespaceBefore.st_mode & (S_ISUID | S_ISGID)) != 0 ||
+        namespaceBefore.st_dev != candidateIdentity->st_dev ||
+        namespaceBefore.st_size <= 0 ||
+        (unsigned long long)namespaceBefore.st_size > PXDiscoveryMaximumManifestBytes) goto cleanup;
+    manifestDescriptor = openat(candidateDescriptor,
+                                PXDiscoveryManifestFileName,
+                                O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC);
+    if (manifestDescriptor < 0 ||
+        !PXDiscoveryDescriptorHasCloseOnExec(manifestDescriptor) ||
+        fstat(manifestDescriptor, &descriptorBefore) != 0 ||
+        !PXDiscoveryStableMetadataMatches(&namespaceBefore, &descriptorBefore)) goto cleanup;
+    data = [NSMutableData dataWithCapacity:(NSUInteger)descriptorBefore.st_size];
+    buffer = malloc(PXDiscoveryReadBufferBytes);
+    if (!data || !buffer) goto cleanup;
+    unsigned long long remaining = (unsigned long long)descriptorBefore.st_size;
+    while (remaining > 0) {
+        size_t request = remaining > PXDiscoveryReadBufferBytes
+            ? PXDiscoveryReadBufferBytes : (size_t)remaining;
+        ssize_t count = -1;
+        do {
+            count = read(manifestDescriptor, buffer, request);
+        } while (count < 0 && errno == EINTR);
+        if (count <= 0 || (unsigned long long)count > remaining) goto cleanup;
+        [data appendBytes:buffer length:(NSUInteger)count];
+        remaining -= (unsigned long long)count;
+    }
+    unsigned char extra = 0;
+    ssize_t extraCount = -1;
+    do {
+        extraCount = read(manifestDescriptor, &extra, 1U);
+    } while (extraCount < 0 && errno == EINTR);
+    if (extraCount != 0 ||
+        fstat(manifestDescriptor, &descriptorAfter) != 0 ||
+        fstatat(candidateDescriptor,
+                PXDiscoveryManifestFileName,
+                &namespaceAfter,
+                AT_SYMLINK_NOFOLLOW) != 0 ||
+        !PXDiscoveryStableMetadataMatches(&descriptorBefore, &descriptorAfter) ||
+        !PXDiscoveryStableMetadataMatches(&descriptorAfter, &namespaceAfter) ||
+        data.length != (NSUInteger)descriptorBefore.st_size) goto cleanup;
+    *manifestIdentityOut = descriptorAfter;
+    result = [data copy];
+cleanup:
+    if (buffer) free(buffer);
+    if (manifestDescriptor >= 0) close(manifestDescriptor);
+    return result;
+}
+
+static NSString *PXDiscoveryInspectCandidate(int bundleDescriptor,
+                                             const struct stat *bundleIdentity,
+                                             NSString *rootPath,
+                                             NSString *bundleIdentifier,
+                                             NSString *candidateName,
+                                             NSMutableSet<NSString *> *acceptedIdentities) {
+    NSData *candidateNameData = nil;
+    char *candidateNameBytes = NULL;
+    int candidateDescriptor = -1;
+    NSString *result = nil;
+    @try {
+        if (!PXDiscoveryValidateLosslessString(candidateName,
+                                               PXDiscoveryMaximumComponentBytes,
+                                               NO,
+                                               YES,
+                                               &candidateNameData)) goto cleanup;
+        candidateNameBytes = PXDiscoveryCopyCString(candidateNameData);
+        if (!candidateNameBytes || PXDiscoveryIsReservedOrHidden(candidateNameBytes)) goto cleanup;
+        struct stat namespaceBefore;
+        struct stat descriptorBefore;
+        if (fstatat(bundleDescriptor,
+                    candidateNameBytes,
+                    &namespaceBefore,
+                    AT_SYMLINK_NOFOLLOW) != 0 ||
+            !S_ISDIR(namespaceBefore.st_mode) ||
+            (namespaceBefore.st_mode & (S_ISUID | S_ISGID)) != 0 ||
+            namespaceBefore.st_dev != bundleIdentity->st_dev) goto cleanup;
+        candidateDescriptor = openat(bundleDescriptor,
+                                     candidateNameBytes,
+                                     O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
+        if (candidateDescriptor < 0 ||
+            !PXDiscoveryDescriptorHasCloseOnExec(candidateDescriptor) ||
+            fstat(candidateDescriptor, &descriptorBefore) != 0 ||
+            !PXDiscoveryStableMetadataMatches(&namespaceBefore, &descriptorBefore)) goto cleanup;
+        struct stat manifestIdentity;
+        NSData *manifestData = PXDiscoveryReadManifestData(candidateDescriptor,
+                                                           &descriptorBefore,
+                                                           &manifestIdentity);
+        if (![manifestData isKindOfClass:[NSData class]]) goto cleanup;
+        NSPropertyListFormat format = NSPropertyListBinaryFormat_v1_0;
+        NSError *parseError = nil;
+        id object = [NSPropertyListSerialization propertyListWithData:manifestData
+                                                              options:NSPropertyListImmutable
+                                                               format:&format
+                                                                error:&parseError];
+        (void)parseError;
+        if (![object isKindOfClass:[NSDictionary class]]) goto cleanup;
+        NSDictionary *manifest = (NSDictionary *)object;
+        NSError *validationError = nil;
+        if (![PXBackupManifestValidator validateManifestObject:manifest
+                                                          error:&validationError]) goto cleanup;
+        (void)validationError;
+        unsigned long long version = 0;
+        if (!PXDiscoveryReadUnsignedIntegral(manifest[@"manifestVersion"], &version) ||
+            (version != 2ULL && version != 3ULL && version != 4ULL)) goto cleanup;
+        NSString *manifestBundleIdentifier = nil;
+        if (!PXDiscoveryReadString(manifest[@"bundleID"], &manifestBundleIdentifier) ||
+            ![manifestBundleIdentifier isEqualToString:bundleIdentifier]) goto cleanup;
+        if (version == 4ULL) {
+            if ((descriptorBefore.st_mode & 07777) != 0700 ||
+                (manifestIdentity.st_mode & 07777) != 0600) goto cleanup;
+            NSDictionary *publication = manifest[@"publication"];
+            NSString *protocol = nil;
+            NSString *contentState = nil;
+            NSString *timestamp = nil;
+            NSString *backupIdentifier = nil;
+            if (![publication isKindOfClass:[NSDictionary class]] ||
+                !PXDiscoveryReadString(publication[@"protocol"], &protocol) ||
+                !PXDiscoveryReadString(publication[@"contentState"], &contentState) ||
+                !PXDiscoveryReadString(manifest[@"timestamp"], &timestamp) ||
+                !PXDiscoveryReadString(manifest[@"backupID"], &backupIdentifier) ||
+                ![protocol isEqualToString:@"atomic-directory-v1"] ||
+                ![contentState isEqualToString:@"complete"] ||
+                !PXDiscoveryTimestampIsCanonical(timestamp) ||
+                !PXDiscoveryBackupIdentifierIsCanonical(backupIdentifier)) goto cleanup;
+            NSString *expectedName = [NSString stringWithFormat:@"%@-%@",
+                                      timestamp,
+                                      backupIdentifier];
+            if (![candidateName isEqualToString:expectedName]) goto cleanup;
+        }
+        struct stat descriptorAfter;
+        struct stat namespaceAfter;
+        struct stat manifestAfter;
+        if (fstat(candidateDescriptor, &descriptorAfter) != 0 ||
+            fstatat(bundleDescriptor,
+                    candidateNameBytes,
+                    &namespaceAfter,
+                    AT_SYMLINK_NOFOLLOW) != 0 ||
+            fstatat(candidateDescriptor,
+                    PXDiscoveryManifestFileName,
+                    &manifestAfter,
+                    AT_SYMLINK_NOFOLLOW) != 0 ||
+            !PXDiscoveryStableMetadataMatches(&descriptorBefore, &descriptorAfter) ||
+            !PXDiscoveryStableMetadataMatches(&descriptorAfter, &namespaceAfter) ||
+            !PXDiscoveryStableMetadataMatches(&manifestIdentity, &manifestAfter)) goto cleanup;
+        NSString *identityKey = [NSString stringWithFormat:@"%llu:%llu",
+                                 (unsigned long long)descriptorAfter.st_dev,
+                                 (unsigned long long)descriptorAfter.st_ino];
+        if ([acceptedIdentities containsObject:identityKey]) goto cleanup;
+        NSString *candidatePath = PXDiscoveryAppendComponent(
+            PXDiscoveryAppendComponent(rootPath, bundleIdentifier), candidateName);
+        NSString *expectedPath = PXDiscoveryAppendComponent(
+            PXDiscoveryAppendComponent(rootPath, bundleIdentifier), candidateName);
+        if (![candidatePath isKindOfClass:[NSString class]] ||
+            ![candidatePath isEqualToString:expectedPath]) goto cleanup;
+        [acceptedIdentities addObject:identityKey];
+        result = candidatePath;
+    } @catch (NSException *exception) {
+        (void)exception;
+        result = nil;
+    }
+cleanup:
+    if (candidateDescriptor >= 0) close(candidateDescriptor);
+    if (candidateNameBytes) free(candidateNameBytes);
+    return result;
+}
+
+@implementation PXBackupDirectoryDiscovery
+
++ (nullable NSArray<NSString *> *)discoverBackupDirectoriesAtBackupRoots:
+    (NSArray<NSString *> *)backupRoots
+    bundleIdentifier:(NSString *)bundleIdentifier
+    error:(NSError **)error {
+    if (error) *error = nil;
+    @try {
+        if (![backupRoots isKindOfClass:[NSArray class]] ||
+            backupRoots.count == 0 || backupRoots.count > PXDiscoveryMaximumRoots) {
+            PXDiscoverySetError(error,
+                                PXBackupDirectoryDiscoveryErrorInvalidInput,
+                                PXDiscoveryInputField,
+                                @"The backup discovery roots are invalid");
+            return nil;
+        }
+        NSData *bundleData = nil;
+        if (!PXDiscoveryValidateLosslessString(bundleIdentifier,
+                                               PXDiscoveryMaximumComponentBytes,
+                                               NO,
+                                               YES,
+                                               &bundleData)) {
+            PXDiscoverySetError(error,
+                                PXBackupDirectoryDiscoveryErrorInvalidInput,
+                                PXDiscoveryBundleField,
+                                @"The backup discovery bundle identifier is invalid");
+            return nil;
+        }
+        char *bundleBytes = PXDiscoveryCopyCString(bundleData);
+        if (!bundleBytes) {
+            PXDiscoverySetError(error,
+                                PXBackupDirectoryDiscoveryErrorInternalInvariantFailed,
+                                PXDiscoveryBundleField,
+                                @"The backup discovery bundle identifier could not be retained");
+            return nil;
+        }
+        NSMutableArray<NSString *> *accepted = [NSMutableArray array];
+        NSMutableSet<NSString *> *acceptedIdentities = [NSMutableSet set];
+        NSMutableSet<NSString *> *scannedBundleIdentities = [NSMutableSet set];
+        NSUInteger aggregateEntries = 0U;
+        BOOL failed = NO;
+        for (id rootValue in backupRoots) {
+            NSData *rootData = nil;
+            if (!PXDiscoveryValidateLosslessString(rootValue,
+                                                   PXDiscoveryMaximumRootPathBytes,
+                                                   YES,
+                                                   NO,
+                                                   &rootData)) {
+                PXDiscoverySetError(error,
+                                    PXBackupDirectoryDiscoveryErrorInvalidInput,
+                                    PXDiscoveryRootField,
+                                    @"A backup discovery root is invalid");
+                failed = YES;
+                break;
+            }
+            NSString *rootPath = (NSString *)rootValue;
+            char *rootBytes = PXDiscoveryCopyCString(rootData);
+            if (!rootBytes) {
+                PXDiscoverySetError(error,
+                                    PXBackupDirectoryDiscoveryErrorInternalInvariantFailed,
+                                    PXDiscoveryRootField,
+                                    @"A backup discovery root could not be retained");
+                failed = YES;
+                break;
+            }
+            struct stat rootNamespace;
+            if (lstat(rootBytes, &rootNamespace) != 0) {
+                int failureErrno = errno;
+                free(rootBytes);
+                if (failureErrno == ENOENT) continue;
+                PXDiscoverySetError(error,
+                                    PXBackupDirectoryDiscoveryErrorRootInspectionFailed,
+                                    PXDiscoveryRootField,
+                                    @"A backup discovery root could not be inspected");
+                failed = YES;
+                break;
+            }
+            if (!S_ISDIR(rootNamespace.st_mode) ||
+                (rootNamespace.st_mode & (S_ISUID | S_ISGID)) != 0) {
+                free(rootBytes);
+                PXDiscoverySetError(error,
+                                    PXBackupDirectoryDiscoveryErrorRootInspectionFailed,
+                                    PXDiscoveryRootField,
+                                    @"A backup discovery root is unsafe");
+                failed = YES;
+                break;
+            }
+            int rootDescriptor = open(rootBytes,
+                                      O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
+            free(rootBytes);
+            if (rootDescriptor < 0) {
+                PXDiscoverySetError(error,
+                                    PXBackupDirectoryDiscoveryErrorRootInspectionFailed,
+                                    PXDiscoveryRootField,
+                                    @"A backup discovery root could not be opened safely");
+                failed = YES;
+                break;
+            }
+            struct stat rootDescriptorStat;
+            if (!PXDiscoveryDescriptorHasCloseOnExec(rootDescriptor) ||
+                fstat(rootDescriptor, &rootDescriptorStat) != 0 ||
+                !PXDiscoveryStableMetadataMatches(&rootNamespace,
+                                                  &rootDescriptorStat)) {
+                close(rootDescriptor);
+                PXDiscoverySetError(error,
+                                    PXBackupDirectoryDiscoveryErrorFilesystemChanged,
+                                    PXDiscoveryRootField,
+                                    @"A backup discovery root identity changed");
+                failed = YES;
+                break;
+            }
+            struct stat bundleNamespace;
+            if (fstatat(rootDescriptor,
+                        bundleBytes,
+                        &bundleNamespace,
+                        AT_SYMLINK_NOFOLLOW) != 0) {
+                int failureErrno = errno;
+                close(rootDescriptor);
+                if (failureErrno == ENOENT) continue;
+                PXDiscoverySetError(error,
+                                    PXBackupDirectoryDiscoveryErrorBundleDirectoryInvalid,
+                                    PXDiscoveryBundleField,
+                                    @"The backup bundle directory could not be inspected");
+                failed = YES;
+                break;
+            }
+            if (!S_ISDIR(bundleNamespace.st_mode) ||
+                (bundleNamespace.st_mode & (S_ISUID | S_ISGID)) != 0 ||
+                bundleNamespace.st_dev != rootDescriptorStat.st_dev) {
+                close(rootDescriptor);
+                PXDiscoverySetError(error,
+                                    PXBackupDirectoryDiscoveryErrorBundleDirectoryInvalid,
+                                    PXDiscoveryBundleField,
+                                    @"The backup bundle directory is unsafe");
+                failed = YES;
+                break;
+            }
+            int bundleDescriptor = openat(rootDescriptor,
+                                          bundleBytes,
+                                          O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
+            if (bundleDescriptor < 0) {
+                close(rootDescriptor);
+                PXDiscoverySetError(error,
+                                    PXBackupDirectoryDiscoveryErrorBundleDirectoryInvalid,
+                                    PXDiscoveryBundleField,
+                                    @"The backup bundle directory could not be opened safely");
+                failed = YES;
+                break;
+            }
+            struct stat bundleDescriptorStat;
+            if (!PXDiscoveryDescriptorHasCloseOnExec(bundleDescriptor) ||
+                fstat(bundleDescriptor, &bundleDescriptorStat) != 0 ||
+                !PXDiscoveryStableMetadataMatches(&bundleNamespace,
+                                                  &bundleDescriptorStat)) {
+                close(bundleDescriptor);
+                close(rootDescriptor);
+                PXDiscoverySetError(error,
+                                    PXBackupDirectoryDiscoveryErrorFilesystemChanged,
+                                    PXDiscoveryBundleField,
+                                    @"The backup bundle directory identity changed");
+                failed = YES;
+                break;
+            }
+            NSString *bundleIdentity = [NSString stringWithFormat:@"%llu:%llu",
+                                        (unsigned long long)bundleDescriptorStat.st_dev,
+                                        (unsigned long long)bundleDescriptorStat.st_ino];
+            if ([scannedBundleIdentities containsObject:bundleIdentity]) {
+                close(bundleDescriptor);
+                close(rootDescriptor);
+                continue;
+            }
+            [scannedBundleIdentities addObject:bundleIdentity];
+            NSError *enumerationError = nil;
+            NSArray<NSString *> *names = PXDiscoveryCopySortedEntryNames(
+                bundleDescriptor,
+                PXDiscoveryMaximumEntriesPerBundleRoot,
+                &aggregateEntries,
+                &enumerationError);
+            if (!names) {
+                close(bundleDescriptor);
+                close(rootDescriptor);
+                if (error) *error = enumerationError;
+                failed = YES;
+                break;
+            }
+            for (NSString *candidateName in names) {
+                if (accepted.count >= PXDiscoveryMaximumAcceptedBackups) {
+                    PXDiscoverySetError(error,
+                                        PXBackupDirectoryDiscoveryErrorLimitExceeded,
+                                        PXDiscoveryTraversalField,
+                                        @"The accepted backup limit was exceeded");
+                    failed = YES;
+                    break;
+                }
+                NSString *path = PXDiscoveryInspectCandidate(bundleDescriptor,
+                                                             &bundleDescriptorStat,
+                                                             rootPath,
+                                                             bundleIdentifier,
+                                                             candidateName,
+                                                             acceptedIdentities);
+                if (path) [accepted addObject:path];
+            }
+            if (!failed) {
+                char *finalRootBytes = PXDiscoveryCopyCString(rootData);
+                struct stat rootNamespaceAfter;
+                struct stat rootDescriptorAfter;
+                struct stat bundleNamespaceAfter;
+                struct stat bundleDescriptorAfter;
+                BOOL authorityStable = finalRootBytes &&
+                    lstat(finalRootBytes, &rootNamespaceAfter) == 0 &&
+                    fstat(rootDescriptor, &rootDescriptorAfter) == 0 &&
+                    fstatat(rootDescriptor,
+                            bundleBytes,
+                            &bundleNamespaceAfter,
+                            AT_SYMLINK_NOFOLLOW) == 0 &&
+                    fstat(bundleDescriptor, &bundleDescriptorAfter) == 0 &&
+                    PXDiscoveryStableMetadataMatches(&rootNamespace,
+                                                     &rootNamespaceAfter) &&
+                    PXDiscoveryStableMetadataMatches(&rootDescriptorStat,
+                                                     &rootDescriptorAfter) &&
+                    PXDiscoveryStableMetadataMatches(&bundleNamespace,
+                                                     &bundleNamespaceAfter) &&
+                    PXDiscoveryStableMetadataMatches(&bundleDescriptorStat,
+                                                     &bundleDescriptorAfter) &&
+                    PXDiscoveryStatIdentityMatches(&rootNamespaceAfter,
+                                                   &rootDescriptorAfter) &&
+                    PXDiscoveryStatIdentityMatches(&bundleNamespaceAfter,
+                                                   &bundleDescriptorAfter);
+                if (finalRootBytes) free(finalRootBytes);
+                if (!authorityStable) {
+                    PXDiscoverySetError(error,
+                                        PXBackupDirectoryDiscoveryErrorFilesystemChanged,
+                                        PXDiscoveryRootField,
+                                        @"The backup discovery authority changed during traversal");
+                    failed = YES;
+                }
+            }
+            close(bundleDescriptor);
+            close(rootDescriptor);
+            if (failed) break;
+        }
+        free(bundleBytes);
+        if (failed) return nil;
+        [accepted sortUsingComparator:^NSComparisonResult(NSString *left,
+                                                          NSString *right) {
+            NSComparisonResult component =
+                [right.lastPathComponent compare:left.lastPathComponent];
+            if (component != NSOrderedSame) return component;
+            return [left compare:right];
+        }];
+        if (error) *error = nil;
+        return [accepted copy];
+    } @catch (NSException *exception) {
+        (void)exception;
+        PXDiscoverySetError(error,
+                            PXBackupDirectoryDiscoveryErrorInternalInvariantFailed,
+                            PXDiscoveryTraversalField,
+                            @"The backup discovery operation failed safely");
+        return nil;
+    }
+}
+
+@end
--- /dev/null
+++ b/PXBackupStaleWorkspaceCleanup.h
@@ -0,0 +1,51 @@
+#import <Foundation/Foundation.h>
+
+NS_ASSUME_NONNULL_BEGIN
+
+@class PXBackupBundleLock;
+
+FOUNDATION_EXPORT NSErrorDomain const PXBackupStaleWorkspaceCleanupErrorDomain;
+FOUNDATION_EXPORT NSString * const PXBackupStaleWorkspaceCleanupErrorFieldPathKey;
+
+typedef NS_ERROR_ENUM(PXBackupStaleWorkspaceCleanupErrorDomain,
+                      PXBackupStaleWorkspaceCleanupErrorCode) {
+    PXBackupStaleWorkspaceCleanupErrorInvalidInput = 1,
+    PXBackupStaleWorkspaceCleanupErrorLockValidationFailed = 2,
+    PXBackupStaleWorkspaceCleanupErrorParentInspectionFailed = 3,
+    PXBackupStaleWorkspaceCleanupErrorTraversalFailed = 4,
+    PXBackupStaleWorkspaceCleanupErrorReservedNameInvalid = 5,
+    PXBackupStaleWorkspaceCleanupErrorUnsafeReservedEntry = 6,
+    PXBackupStaleWorkspaceCleanupErrorEntryChanged = 7,
+    PXBackupStaleWorkspaceCleanupErrorLimitExceeded = 8,
+    PXBackupStaleWorkspaceCleanupErrorQuarantineFailed = 9,
+    PXBackupStaleWorkspaceCleanupErrorRollbackFailed = 10,
+    PXBackupStaleWorkspaceCleanupErrorRemovalFailed = 11,
+    PXBackupStaleWorkspaceCleanupErrorDurabilityFailed = 12,
+    PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete = 13,
+    PXBackupStaleWorkspaceCleanupErrorFilesystemChanged = 14,
+    PXBackupStaleWorkspaceCleanupErrorAlreadyPerformed = 15,
+    PXBackupStaleWorkspaceCleanupErrorPublishedEntryDetected = 16,
+    PXBackupStaleWorkspaceCleanupErrorInternalInvariantFailed = 17,
+    PXBackupStaleWorkspaceCleanupErrorMissingError = 18,
+};
+
+__attribute__((objc_subclassing_restricted))
+@interface PXBackupStaleWorkspaceCleanup : NSObject
+
+@property (nonatomic, copy, readonly) NSString *canonicalBundleDirectoryPath;
+@property (nonatomic, readonly) BOOL cleanupAttempted;
+@property (nonatomic, readonly) NSUInteger cleanedWorkspaceCount;
+@property (nonatomic, readonly) NSUInteger removedEntryCount;
+
++ (nullable instancetype)cleanupForBundleLock:(PXBackupBundleLock *)bundleLock
+                                        error:(NSError * _Nullable * _Nullable)error;
+
+- (BOOL)removeStaleWorkspacesWithError:(NSError * _Nullable * _Nullable)error;
+- (BOOL)validateIdentityWithError:(NSError * _Nullable * _Nullable)error;
+
+- (instancetype)init NS_UNAVAILABLE;
++ (instancetype)new NS_UNAVAILABLE;
+
+@end
+
+NS_ASSUME_NONNULL_END
--- /dev/null
+++ b/PXBackupStaleWorkspaceCleanup.m
@@ -0,0 +1,1801 @@
+#import "PXBackupStaleWorkspaceCleanup.h"
+#import "PXBackupBundleLock.h"
+
+#include <dirent.h>
+#include <errno.h>
+#include <fcntl.h>
+#include <limits.h>
+#include <stdint.h>
+#include <stdio.h>
+#include <stdlib.h>
+#include <string.h>
+#include <sys/stat.h>
+#include <sys/types.h>
+#include <unistd.h>
+
+NSErrorDomain const PXBackupStaleWorkspaceCleanupErrorDomain =
+    @"com.hydra.projectx.backup-stale-workspace-cleanup";
+NSString * const PXBackupStaleWorkspaceCleanupErrorFieldPathKey = @"fieldPath";
+
+static NSString * const PXBackupStaleWorkspaceCleanupField = @"$.staleCleanup";
+static NSString * const PXBackupStaleWorkspaceCleanupLockField = @"$.staleCleanup.lock";
+static NSString * const PXBackupStaleWorkspaceCleanupParentField = @"$.staleCleanup.parent";
+static NSString * const PXBackupStaleWorkspaceCleanupWorkspaceField = @"$.staleCleanup.workspace";
+static NSString * const PXBackupStaleWorkspaceCleanupEntryField = @"$.staleCleanup.entry";
+static NSString * const PXBackupStaleWorkspaceCleanupDurabilityField = @"$.staleCleanup.durability";
+static NSString * const PXBackupStaleWorkspaceCleanupPublicationField = @"$.staleCleanup.publication";
+
+static const NSUInteger PXBackupStaleWorkspaceCleanupMaximumDepth = 64U;
+static const NSUInteger PXBackupStaleWorkspaceCleanupMaximumVisitedEntries = 16384U;
+static const NSUInteger PXBackupStaleWorkspaceCleanupMaximumComponentBytes = 255U;
+static const NSUInteger PXBackupStaleWorkspaceCleanupMaximumWorkspacePathBytes = 4096U;
+static const unsigned long long PXBackupStaleWorkspaceCleanupMaximumAccumulatedNameBytes =
+    8ULL * 1024ULL * 1024ULL;
+static const char PXBackupStaleWorkspaceCleanupQuarantinePrefix[] =
+    ".weaponx-cleanup-quarantine-";
+static const NSUInteger PXBackupStaleWorkspaceCleanupQuarantineRandomByteCount = 16U;
+static const NSUInteger PXBackupStaleWorkspaceCleanupQuarantineAttemptLimit = 16U;
+static const NSUInteger PXBackupStaleWorkspaceCleanupMaximumTopLevelCandidates = 256U;
+static const char PXBackupStaleWorkspaceCleanupPartialPrefix[] =
+    ".weaponx-backup-partial-";
+
+#if defined(__APPLE__)
+#define PX_BACKUP_CLEANUP_MTIME_SEC(value) ((value).st_mtimespec.tv_sec)
+#define PX_BACKUP_CLEANUP_MTIME_NSEC(value) ((value).st_mtimespec.tv_nsec)
+#define PX_BACKUP_CLEANUP_CTIME_SEC(value) ((value).st_ctimespec.tv_sec)
+#define PX_BACKUP_CLEANUP_CTIME_NSEC(value) ((value).st_ctimespec.tv_nsec)
+#else
+#define PX_BACKUP_CLEANUP_MTIME_SEC(value) ((value).st_mtim.tv_sec)
+#define PX_BACKUP_CLEANUP_MTIME_NSEC(value) ((value).st_mtim.tv_nsec)
+#define PX_BACKUP_CLEANUP_CTIME_SEC(value) ((value).st_ctim.tv_sec)
+#define PX_BACKUP_CLEANUP_CTIME_NSEC(value) ((value).st_ctim.tv_nsec)
+#endif
+
+typedef struct {
+    NSUInteger visitedEntries;
+    unsigned long long accumulatedNameBytes;
+    NSUInteger removedEntries;
+    BOOL destructiveMutationOccurred;
+    dev_t workspaceDevice;
+} PXBackupStaleWorkspaceCleanupTraversalState;
+
+static void PXBackupStaleWorkspaceCleanupSetError(
+    NSError **error,
+    PXBackupStaleWorkspaceCleanupErrorCode code,
+    NSString *field,
+    NSString *description) {
+    if (!error) return;
+    *error = [NSError errorWithDomain:PXBackupStaleWorkspaceCleanupErrorDomain
+                                 code:code
+                             userInfo:@{
+                                 NSLocalizedDescriptionKey: description,
+                                 PXBackupStaleWorkspaceCleanupErrorFieldPathKey: field,
+                             }];
+}
+
+static BOOL PXBackupStaleWorkspaceCleanupStatIdentityMatches(const struct stat *left,
+                                                       const struct stat *right) {
+    return left && right && left->st_dev == right->st_dev &&
+           left->st_ino == right->st_ino &&
+           (left->st_mode & S_IFMT) == (right->st_mode & S_IFMT);
+}
+
+static BOOL PXBackupStaleWorkspaceCleanupStableFileMatches(const struct stat *left,
+                                                     const struct stat *right) {
+    return PXBackupStaleWorkspaceCleanupStatIdentityMatches(left, right) &&
+           left->st_mode == right->st_mode && left->st_nlink == right->st_nlink &&
+           left->st_size == right->st_size &&
+           PX_BACKUP_CLEANUP_MTIME_SEC(*left) == PX_BACKUP_CLEANUP_MTIME_SEC(*right) &&
+           PX_BACKUP_CLEANUP_MTIME_NSEC(*left) == PX_BACKUP_CLEANUP_MTIME_NSEC(*right) &&
+           PX_BACKUP_CLEANUP_CTIME_SEC(*left) == PX_BACKUP_CLEANUP_CTIME_SEC(*right) &&
+           PX_BACKUP_CLEANUP_CTIME_NSEC(*left) == PX_BACKUP_CLEANUP_CTIME_NSEC(*right);
+}
+
+static BOOL PXBackupStaleWorkspaceCleanupDescriptorHasCloseOnExec(int descriptor) {
+    if (descriptor < 0) return NO;
+    int flags = -1;
+    do {
+        flags = fcntl(descriptor, F_GETFD);
+    } while (flags < 0 && errno == EINTR);
+    return flags >= 0 && (flags & FD_CLOEXEC) != 0;
+}
+
+static int PXBackupStaleWorkspaceCleanupDuplicateDescriptor(int descriptor) {
+    if (descriptor < 0) return -1;
+    int duplicate = -1;
+    do {
+        duplicate = fcntl(descriptor, F_DUPFD_CLOEXEC, 0);
+    } while (duplicate < 0 && errno == EINTR);
+    if (duplicate < 0 ||
+        !PXBackupStaleWorkspaceCleanupDescriptorHasCloseOnExec(duplicate)) {
+        if (duplicate >= 0) close(duplicate);
+        return -1;
+    }
+    return duplicate;
+}
+
+static BOOL PXBackupStaleWorkspaceCleanupStrictSync(int descriptor) {
+    if (descriptor < 0) return NO;
+    int result = -1;
+    do {
+        result = fsync(descriptor);
+    } while (result < 0 && errno == EINTR);
+    return result == 0;
+}
+
+
+typedef enum {
+    PXBackupStaleWorkspaceCleanupCaptureTypeRegularFile = 1,
+    PXBackupStaleWorkspaceCleanupCaptureTypeDirectory = 2,
+} PXBackupStaleWorkspaceCleanupCaptureType;
+
+static BOOL PXBackupStaleWorkspaceCleanupEntryIsAbsent(int parentDescriptor,
+                                                 const char *name);
+
+static BOOL PXBackupStaleWorkspaceCleanupMoveNoReplace(
+    int sourceParentDescriptor,
+    const char *sourceName,
+    int destinationParentDescriptor,
+    const char *destinationName,
+    int *failureErrnoOut) {
+    if (failureErrnoOut) *failureErrnoOut = 0;
+    if (sourceParentDescriptor < 0 || destinationParentDescriptor < 0 ||
+        !sourceName || sourceName[0] == '\0' ||
+        !destinationName || destinationName[0] == '\0') {
+        if (failureErrnoOut) *failureErrnoOut = EINVAL;
+        return NO;
+    }
+    int result = -1;
+    int failureErrno = 0;
+    do {
+        result = renameatx_np(sourceParentDescriptor,
+                              sourceName,
+                              destinationParentDescriptor,
+                              destinationName,
+                              RENAME_EXCL);
+        failureErrno = result == 0 ? 0 : errno;
+    } while (result < 0 && failureErrno == EINTR);
+    if (result == 0) return YES;
+    if (failureErrnoOut) *failureErrnoOut = failureErrno;
+    return NO;
+}
+
+static BOOL PXBackupStaleWorkspaceCleanupGenerateQuarantineName(
+    char *buffer,
+    size_t bufferSize) {
+    static const char lowercaseHex[] = "0123456789abcdef";
+    const size_t prefixLength = sizeof(PXBackupStaleWorkspaceCleanupQuarantinePrefix) - 1U;
+    const size_t suffixLength = PXBackupStaleWorkspaceCleanupQuarantineRandomByteCount * 2U;
+    const size_t requiredLength = prefixLength + suffixLength + 1U;
+    if (!buffer || bufferSize < requiredLength ||
+        requiredLength - 1U > PXBackupStaleWorkspaceCleanupMaximumComponentBytes) return NO;
+    unsigned char randomBytes[PXBackupStaleWorkspaceCleanupQuarantineRandomByteCount];
+    arc4random_buf(randomBytes, sizeof(randomBytes));
+    memcpy(buffer, PXBackupStaleWorkspaceCleanupQuarantinePrefix, prefixLength);
+    for (size_t index = 0; index < sizeof(randomBytes); index++) {
+        unsigned char byte = randomBytes[index];
+        buffer[prefixLength + (index * 2U)] = lowercaseHex[(byte >> 4U) & 0x0fU];
+        buffer[prefixLength + (index * 2U) + 1U] = lowercaseHex[byte & 0x0fU];
+    }
+    buffer[requiredLength - 1U] = '\0';
+    return YES;
+}
+
+static BOOL PXBackupStaleWorkspaceCleanupCapturedBindingValid(
+    int parentDescriptor,
+    const char *quarantineName,
+    int retainedDescriptor,
+    const struct stat *retainedIdentity,
+    PXBackupStaleWorkspaceCleanupCaptureType captureType,
+    dev_t expectedDevice,
+    BOOL requireWorkspaceMode,
+    struct stat *currentOut) {
+    if (parentDescriptor < 0 || retainedDescriptor < 0 ||
+        !quarantineName || quarantineName[0] == '\0' || !retainedIdentity) return NO;
+    struct stat namespaceStat;
+    struct stat descriptorStat;
+    if (fstatat(parentDescriptor,
+                quarantineName,
+                &namespaceStat,
+                AT_SYMLINK_NOFOLLOW) != 0 ||
+        fstat(retainedDescriptor, &descriptorStat) != 0 ||
+        namespaceStat.st_dev != expectedDevice ||
+        descriptorStat.st_dev != expectedDevice ||
+        (namespaceStat.st_mode & (S_ISUID | S_ISGID)) != 0 ||
+        (descriptorStat.st_mode & (S_ISUID | S_ISGID)) != 0 ||
+        !PXBackupStaleWorkspaceCleanupStatIdentityMatches(&namespaceStat,
+                                                   &descriptorStat) ||
+        !PXBackupStaleWorkspaceCleanupStatIdentityMatches(retainedIdentity,
+                                                   &descriptorStat) ||
+        !PXBackupStaleWorkspaceCleanupDescriptorHasCloseOnExec(retainedDescriptor)) return NO;
+    if (captureType == PXBackupStaleWorkspaceCleanupCaptureTypeRegularFile) {
+        if (!S_ISREG(namespaceStat.st_mode) || !S_ISREG(descriptorStat.st_mode) ||
+            namespaceStat.st_nlink != 1 || descriptorStat.st_nlink != 1 ||
+            namespaceStat.st_mode != retainedIdentity->st_mode ||
+            descriptorStat.st_mode != retainedIdentity->st_mode ||
+            namespaceStat.st_size != retainedIdentity->st_size ||
+            descriptorStat.st_size != retainedIdentity->st_size ||
+            PX_BACKUP_CLEANUP_MTIME_SEC(namespaceStat) !=
+                PX_BACKUP_CLEANUP_MTIME_SEC(*retainedIdentity) ||
+            PX_BACKUP_CLEANUP_MTIME_NSEC(namespaceStat) !=
+                PX_BACKUP_CLEANUP_MTIME_NSEC(*retainedIdentity) ||
+            PX_BACKUP_CLEANUP_MTIME_SEC(descriptorStat) !=
+                PX_BACKUP_CLEANUP_MTIME_SEC(*retainedIdentity) ||
+            PX_BACKUP_CLEANUP_MTIME_NSEC(descriptorStat) !=
+                PX_BACKUP_CLEANUP_MTIME_NSEC(*retainedIdentity)) return NO;
+    } else if (captureType == PXBackupStaleWorkspaceCleanupCaptureTypeDirectory) {
+        if (!S_ISDIR(namespaceStat.st_mode) || !S_ISDIR(descriptorStat.st_mode) ||
+            (requireWorkspaceMode &&
+             ((namespaceStat.st_mode & 07777) != 0700 ||
+              (descriptorStat.st_mode & 07777) != 0700))) return NO;
+    } else {
+        return NO;
+    }
+    if (currentOut) *currentOut = descriptorStat;
+    return YES;
+}
+
+static BOOL PXBackupStaleWorkspaceCleanupRollbackCapturedMismatch(
+    int parentDescriptor,
+    const char *quarantineName,
+    const char *originalName) {
+    if (!PXBackupStaleWorkspaceCleanupEntryIsAbsent(parentDescriptor, originalName)) {
+        return NO;
+    }
+    int rollbackErrno = 0;
+    if (!PXBackupStaleWorkspaceCleanupMoveNoReplace(parentDescriptor,
+                                             quarantineName,
+                                             parentDescriptor,
+                                             originalName,
+                                             &rollbackErrno) ||
+        !PXBackupStaleWorkspaceCleanupStrictSync(parentDescriptor) ||
+        !PXBackupStaleWorkspaceCleanupEntryIsAbsent(parentDescriptor, quarantineName)) {
+        return NO;
+    }
+    struct stat restored;
+    return fstatat(parentDescriptor,
+                   originalName,
+                   &restored,
+                   AT_SYMLINK_NOFOLLOW) == 0;
+}
+
+static BOOL PXBackupStaleWorkspaceCleanupCaptureEntry(
+    int parentDescriptor,
+    const char *sourceName,
+    int retainedDescriptor,
+    const struct stat *retainedIdentity,
+    PXBackupStaleWorkspaceCleanupCaptureType captureType,
+    dev_t expectedDevice,
+    BOOL requireWorkspaceMode,
+    BOOL priorDestructiveMutation,
+    char **quarantineNameOut,
+    NSError **error) {
+    if (quarantineNameOut) *quarantineNameOut = NULL;
+    if (parentDescriptor < 0 || retainedDescriptor < 0 ||
+        !sourceName || sourceName[0] == '\0' || !retainedIdentity ||
+        !quarantineNameOut) {
+        PXBackupStaleWorkspaceCleanupSetError(
+            error,
+            PXBackupStaleWorkspaceCleanupErrorInvalidInput,
+            PXBackupStaleWorkspaceCleanupEntryField,
+            @"The cleanup capture inputs are invalid");
+        return NO;
+    }
+    const size_t quarantineCapacity =
+        sizeof(PXBackupStaleWorkspaceCleanupQuarantinePrefix) +
+        (PXBackupStaleWorkspaceCleanupQuarantineRandomByteCount * 2U);
+    char quarantineName[sizeof(PXBackupStaleWorkspaceCleanupQuarantinePrefix) +
+                        (PXBackupStaleWorkspaceCleanupQuarantineRandomByteCount * 2U)];
+    BOOL moved = NO;
+    int moveErrno = 0;
+    for (NSUInteger attempt = 0;
+         attempt < PXBackupStaleWorkspaceCleanupQuarantineAttemptLimit;
+         attempt++) {
+        if (!PXBackupStaleWorkspaceCleanupGenerateQuarantineName(quarantineName,
+                                                          quarantineCapacity)) {
+            PXBackupStaleWorkspaceCleanupSetError(
+                error,
+                priorDestructiveMutation
+                    ? PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete
+                    : PXBackupStaleWorkspaceCleanupErrorLimitExceeded,
+                PXBackupStaleWorkspaceCleanupEntryField,
+                @"A private cleanup quarantine name could not be generated");
+            return NO;
+        }
+        moveErrno = 0;
+        if (PXBackupStaleWorkspaceCleanupMoveNoReplace(parentDescriptor,
+                                                sourceName,
+                                                parentDescriptor,
+                                                quarantineName,
+                                                &moveErrno)) {
+            moved = YES;
+            break;
+        }
+        if (moveErrno == EEXIST || moveErrno == ENOTEMPTY) continue;
+        PXBackupStaleWorkspaceCleanupSetError(
+            error,
+            priorDestructiveMutation
+                ? PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete
+                : PXBackupStaleWorkspaceCleanupErrorEntryChanged,
+            PXBackupStaleWorkspaceCleanupEntryField,
+            @"A cleanup entry changed before atomic capture");
+        return NO;
+    }
+    if (!moved) {
+        PXBackupStaleWorkspaceCleanupSetError(
+            error,
+            priorDestructiveMutation
+                ? PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete
+                : PXBackupStaleWorkspaceCleanupErrorRemovalFailed,
+            PXBackupStaleWorkspaceCleanupEntryField,
+            @"A private cleanup quarantine name could not be reserved");
+        return NO;
+    }
+    BOOL originalAbsent =
+        PXBackupStaleWorkspaceCleanupEntryIsAbsent(parentDescriptor, sourceName);
+    BOOL exactCapture = originalAbsent &&
+        PXBackupStaleWorkspaceCleanupCapturedBindingValid(parentDescriptor,
+                                                   quarantineName,
+                                                   retainedDescriptor,
+                                                   retainedIdentity,
+                                                   captureType,
+                                                   expectedDevice,
+                                                   requireWorkspaceMode,
+                                                   NULL);
+    if (!exactCapture) {
+        BOOL rollbackSucceeded = originalAbsent &&
+            PXBackupStaleWorkspaceCleanupRollbackCapturedMismatch(parentDescriptor,
+                                                           quarantineName,
+                                                           sourceName);
+        PXBackupStaleWorkspaceCleanupSetError(
+            error,
+            (!rollbackSucceeded && priorDestructiveMutation)
+                ? PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete
+                : PXBackupStaleWorkspaceCleanupErrorEntryChanged,
+            PXBackupStaleWorkspaceCleanupEntryField,
+            rollbackSucceeded
+                ? @"A changed cleanup entry was restored without deletion"
+                : @"A changed cleanup entry could not be restored safely");
+        return NO;
+    }
+    size_t quarantineLength = strlen(quarantineName);
+    if (quarantineLength == 0 || quarantineLength > SIZE_MAX - 1U) {
+        BOOL rollbackSucceeded =
+            PXBackupStaleWorkspaceCleanupRollbackCapturedMismatch(parentDescriptor,
+                                                           quarantineName,
+                                                           sourceName);
+        PXBackupStaleWorkspaceCleanupSetError(
+            error,
+            (!rollbackSucceeded && priorDestructiveMutation)
+                ? PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete
+                : PXBackupStaleWorkspaceCleanupErrorLimitExceeded,
+            PXBackupStaleWorkspaceCleanupEntryField,
+            @"The private cleanup quarantine name exceeded fixed limits");
+        return NO;
+    }
+    char *retainedName = malloc(quarantineLength + 1U);
+    if (!retainedName) {
+        BOOL rollbackSucceeded =
+            PXBackupStaleWorkspaceCleanupRollbackCapturedMismatch(parentDescriptor,
+                                                           quarantineName,
+                                                           sourceName);
+        PXBackupStaleWorkspaceCleanupSetError(
+            error,
+            (!rollbackSucceeded && priorDestructiveMutation)
+                ? PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete
+                : PXBackupStaleWorkspaceCleanupErrorLimitExceeded,
+            PXBackupStaleWorkspaceCleanupEntryField,
+            @"The private cleanup quarantine name could not be retained");
+        return NO;
+    }
+    memcpy(retainedName, quarantineName, quarantineLength + 1U);
+    *quarantineNameOut = retainedName;
+    return YES;
+}
+
+static BOOL PXBackupStaleWorkspaceCleanupStringContainsNUL(NSString *value) {
+    if (![value isKindOfClass:[NSString class]]) return YES;
+    for (NSUInteger index = 0; index < value.length; index++) {
+        if ([value characterAtIndex:index] == 0) return YES;
+    }
+    return NO;
+}
+
+static BOOL PXBackupStaleWorkspaceCleanupStringContainsControl(NSString *value) {
+    if (![value isKindOfClass:[NSString class]]) return YES;
+    for (NSUInteger index = 0; index < value.length; index++) {
+        unichar character = [value characterAtIndex:index];
+        if (character < 0x20 || character == 0x7f) return YES;
+    }
+    return NO;
+}
+
+static NSData *PXBackupStaleWorkspaceCleanupLosslessUTF8Data(NSString *value,
+                                                       NSUInteger maximumBytes,
+                                                       BOOL requireAbsolute) {
+    if (![value isKindOfClass:[NSString class]] || value.length == 0 ||
+        PXBackupStaleWorkspaceCleanupStringContainsNUL(value) ||
+        (requireAbsolute && ![value hasPrefix:@"/"])) return nil;
+    NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding
+                        allowLossyConversion:NO];
+    if (!data || data.length == 0 || data.length > maximumBytes) return nil;
+    NSString *roundTrip = [[NSString alloc] initWithData:data
+                                                encoding:NSUTF8StringEncoding];
+    return roundTrip && [roundTrip isEqualToString:value] ? data : nil;
+}
+
+static BOOL PXBackupStaleWorkspaceCleanupValidateComponentString(NSString *component,
+                                                           NSData **dataOut) {
+    if (dataOut) *dataOut = nil;
+    NSData *data = PXBackupStaleWorkspaceCleanupLosslessUTF8Data(
+        component,
+        PXBackupStaleWorkspaceCleanupMaximumComponentBytes,
+        NO);
+    if (!data || PXBackupStaleWorkspaceCleanupStringContainsControl(component) ||
+        [component isEqualToString:@"."] ||
+        [component isEqualToString:@".."] ||
+        [component containsString:@"/"] ||
+        [component containsString:@"\\"]) return NO;
+    if (dataOut) *dataOut = data;
+    return YES;
+}
+
+static BOOL PXBackupStaleWorkspaceCleanupValidateEntryName(const char *name,
+                                                     NSUInteger *lengthOut,
+                                                     NSData **dataOut) {
+    if (lengthOut) *lengthOut = 0;
+    if (dataOut) *dataOut = nil;
+    if (!name) return NO;
+    size_t length = 0;
+    while (length <= PXBackupStaleWorkspaceCleanupMaximumComponentBytes &&
+           name[length] != '\0') {
+        length += 1U;
+    }
+    if (length == 0 || length > PXBackupStaleWorkspaceCleanupMaximumComponentBytes ||
+        (length == 1U && name[0] == '.') ||
+        (length == 2U && name[0] == '.' && name[1] == '.')) return NO;
+    for (size_t index = 0; index < length; index++) {
+        unsigned char byte = (unsigned char)name[index];
+        if (byte == '/' || byte == '\\' || byte < 0x20 || byte == 0x7f) return NO;
+    }
+    NSData *data = [NSData dataWithBytes:name length:length];
+    NSString *string = [[NSString alloc] initWithData:data
+                                              encoding:NSUTF8StringEncoding];
+    NSData *roundTrip = [string dataUsingEncoding:NSUTF8StringEncoding
+                              allowLossyConversion:NO];
+    if (!string || !roundTrip || ![roundTrip isEqualToData:data] ||
+        PXBackupStaleWorkspaceCleanupStringContainsControl(string)) return NO;
+    if (lengthOut) *lengthOut = (NSUInteger)length;
+    if (dataOut) *dataOut = data;
+    return YES;
+}
+
+static char *PXBackupStaleWorkspaceCleanupCopyCString(NSData *data) {
+    if (![data isKindOfClass:[NSData class]] || data.length == 0 ||
+        data.length > SIZE_MAX - 1U) return NULL;
+    char *bytes = malloc(data.length + 1U);
+    if (!bytes) return NULL;
+    memcpy(bytes, data.bytes, data.length);
+    bytes[data.length] = '\0';
+    return bytes;
+}
+
+static BOOL PXBackupStaleWorkspaceCleanupEntryIsAbsent(int parentDescriptor,
+                                                 const char *name) {
+    if (parentDescriptor < 0 || !name || name[0] == '\0') return NO;
+    struct stat current;
+    if (fstatat(parentDescriptor, name, &current, AT_SYMLINK_NOFOLLOW) == 0) {
+        return NO;
+    }
+    return errno == ENOENT;
+}
+
+static BOOL PXBackupStaleWorkspaceCleanupPathMatchesDescriptor(
+    NSString *path,
+    int descriptor,
+    const struct stat *expected,
+    BOOL requireWorkspaceMode,
+    struct stat *currentOut) {
+    NSData *pathData = PXBackupStaleWorkspaceCleanupLosslessUTF8Data(
+        path,
+        PXBackupStaleWorkspaceCleanupMaximumWorkspacePathBytes,
+        YES);
+    char *pathBytes = PXBackupStaleWorkspaceCleanupCopyCString(pathData);
+    if (!pathBytes || descriptor < 0 || !expected) {
+        free(pathBytes);
+        return NO;
+    }
+    struct stat pathStat;
+    struct stat descriptorStat;
+    BOOL valid = lstat(pathBytes, &pathStat) == 0 &&
+                 !S_ISLNK(pathStat.st_mode) && S_ISDIR(pathStat.st_mode) &&
+                 (pathStat.st_mode & (S_ISUID | S_ISGID)) == 0 &&
+                 fstat(descriptor, &descriptorStat) == 0 &&
+                 S_ISDIR(descriptorStat.st_mode) &&
+                 (descriptorStat.st_mode & (S_ISUID | S_ISGID)) == 0 &&
+                 (!requireWorkspaceMode ||
+                  (descriptorStat.st_mode & 07777) == 0700) &&
+                 PXBackupStaleWorkspaceCleanupStatIdentityMatches(&pathStat,
+                                                           &descriptorStat) &&
+                 PXBackupStaleWorkspaceCleanupStatIdentityMatches(expected,
+                                                           &descriptorStat) &&
+                 PXBackupStaleWorkspaceCleanupDescriptorHasCloseOnExec(descriptor);
+    if (valid && currentOut) *currentOut = descriptorStat;
+    free(pathBytes);
+    return valid;
+}
+
+static BOOL PXBackupStaleWorkspaceCleanupDirectoryBindingValid(
+    int parentDescriptor,
+    const char *name,
+    int descriptor,
+    const struct stat *expected,
+    dev_t expectedDevice,
+    BOOL requireWorkspaceMode,
+    struct stat *currentOut) {
+    if (parentDescriptor < 0 || descriptor < 0 || !name || name[0] == '\0' ||
+        !expected) return NO;
+    struct stat namespaceStat;
+    struct stat descriptorStat;
+    if (fstatat(parentDescriptor,
+                name,
+                &namespaceStat,
+                AT_SYMLINK_NOFOLLOW) != 0 ||
+        !S_ISDIR(namespaceStat.st_mode) ||
+        (namespaceStat.st_mode & (S_ISUID | S_ISGID)) != 0 ||
+        fstat(descriptor, &descriptorStat) != 0 ||
+        !S_ISDIR(descriptorStat.st_mode) ||
+        (descriptorStat.st_mode & (S_ISUID | S_ISGID)) != 0 ||
+        (requireWorkspaceMode && (descriptorStat.st_mode & 07777) != 0700) ||
+        namespaceStat.st_dev != expectedDevice ||
+        descriptorStat.st_dev != expectedDevice ||
+        !PXBackupStaleWorkspaceCleanupStatIdentityMatches(&namespaceStat,
+                                                   &descriptorStat) ||
+        !PXBackupStaleWorkspaceCleanupStatIdentityMatches(expected,
+                                                   &descriptorStat) ||
+        !PXBackupStaleWorkspaceCleanupDescriptorHasCloseOnExec(descriptor)) return NO;
+    if (currentOut) *currentOut = descriptorStat;
+    return YES;
+}
+
+static BOOL PXBackupStaleWorkspaceCleanupReadDirectory(
+    int descriptor,
+    PXBackupStaleWorkspaceCleanupTraversalState *state,
+    BOOL collectNames,
+    NSArray<NSData *> **namesOut,
+    BOOL *emptyOut,
+    NSError **error) {
+    if (namesOut) *namesOut = nil;
+    if (emptyOut) *emptyOut = NO;
+    if (descriptor < 0 || (collectNames && !state)) {
+        PXBackupStaleWorkspaceCleanupSetError(
+            error,
+            PXBackupStaleWorkspaceCleanupErrorTraversalFailed,
+            PXBackupStaleWorkspaceCleanupEntryField,
+            @"The cleanup directory could not be traversed");
+        return NO;
+    }
+    int duplicate = PXBackupStaleWorkspaceCleanupDuplicateDescriptor(descriptor);
+    if (duplicate < 0) {
+        PXBackupStaleWorkspaceCleanupSetError(
+            error,
+            PXBackupStaleWorkspaceCleanupErrorTraversalFailed,
+            PXBackupStaleWorkspaceCleanupEntryField,
+            @"The cleanup directory could not be traversed");
+        return NO;
+    }
+    DIR *directory = fdopendir(duplicate);
+    if (!directory) {
+        close(duplicate);
+        PXBackupStaleWorkspaceCleanupSetError(
+            error,
+            PXBackupStaleWorkspaceCleanupErrorTraversalFailed,
+            PXBackupStaleWorkspaceCleanupEntryField,
+            @"The cleanup directory could not be traversed");
+        return NO;
+    }
+    NSMutableArray<NSData *> *names = collectNames ? [NSMutableArray array] : nil;
+    BOOL empty = YES;
+    BOOL valid = YES;
+    for (;;) {
+        errno = 0;
+        struct dirent *entry = readdir(directory);
+        if (!entry) {
+            if (errno != 0) valid = NO;
+            break;
+        }
+        if (strcmp(entry->d_name, ".") == 0 ||
+            strcmp(entry->d_name, "..") == 0) continue;
+        empty = NO;
+        if (!collectNames) continue;
+        NSUInteger nameLength = 0;
+        NSData *nameData = nil;
+        if (!PXBackupStaleWorkspaceCleanupValidateEntryName(entry->d_name,
+                                                     &nameLength,
+                                                     &nameData)) {
+            PXBackupStaleWorkspaceCleanupSetError(
+                error,
+                PXBackupStaleWorkspaceCleanupErrorUnsafeReservedEntry,
+                PXBackupStaleWorkspaceCleanupEntryField,
+                @"The cleanup tree contains an unsafe entry name");
+            valid = NO;
+            break;
+        }
+        if (state->visitedEntries >=
+                PXBackupStaleWorkspaceCleanupMaximumVisitedEntries ||
+            nameLength > ULLONG_MAX - state->accumulatedNameBytes ||
+            state->accumulatedNameBytes + nameLength >
+                PXBackupStaleWorkspaceCleanupMaximumAccumulatedNameBytes) {
+            PXBackupStaleWorkspaceCleanupSetError(
+                error,
+                PXBackupStaleWorkspaceCleanupErrorLimitExceeded,
+                PXBackupStaleWorkspaceCleanupEntryField,
+                @"The cleanup tree exceeds fixed traversal limits");
+            valid = NO;
+            break;
+        }
+        state->visitedEntries += 1U;
+        state->accumulatedNameBytes += nameLength;
+        [names addObject:nameData];
+    }
+    if (closedir(directory) != 0 && valid) valid = NO;
+    if (!valid) {
+        if (error && !*error) {
+            PXBackupStaleWorkspaceCleanupSetError(
+                error,
+                PXBackupStaleWorkspaceCleanupErrorTraversalFailed,
+                PXBackupStaleWorkspaceCleanupEntryField,
+                @"The cleanup directory scan failed");
+        }
+        return NO;
+    }
+    if (collectNames && namesOut) *namesOut = [names copy];
+    if (emptyOut) *emptyOut = empty;
+    return YES;
+}
+
+static BOOL PXBackupStaleWorkspaceCleanupDirectoryIsEmpty(int descriptor,
+                                                    BOOL *emptyOut,
+                                                    NSError **error) {
+    return PXBackupStaleWorkspaceCleanupReadDirectory(descriptor,
+                                               NULL,
+                                               NO,
+                                               NULL,
+                                               emptyOut,
+                                               error);
+}
+
+static BOOL PXBackupStaleWorkspaceCleanupScanEntryNames(
+    int descriptor,
+    PXBackupStaleWorkspaceCleanupTraversalState *state,
+    NSArray<NSData *> **namesOut,
+    NSError **error) {
+    return PXBackupStaleWorkspaceCleanupReadDirectory(descriptor,
+                                               state,
+                                               YES,
+                                               namesOut,
+                                               NULL,
+                                               error);
+}
+
+static BOOL PXBackupStaleWorkspaceCleanupRemoveDirectoryContents(
+    int descriptor,
+    const struct stat *directoryIdentity,
+    NSUInteger depth,
+    PXBackupStaleWorkspaceCleanupTraversalState *state,
+    NSError **error);
+
+static BOOL PXBackupStaleWorkspaceCleanupRemoveRegularFile(
+    int parentDescriptor,
+    const char *name,
+    const struct stat *observed,
+    PXBackupStaleWorkspaceCleanupTraversalState *state,
+    NSError **error) {
+    if (!observed || !state || !S_ISREG(observed->st_mode) ||
+        observed->st_dev != state->workspaceDevice ||
+        (observed->st_mode & (S_ISUID | S_ISGID)) != 0 ||
+        observed->st_nlink != 1) {
+        PXBackupStaleWorkspaceCleanupSetError(
+            error,
+            PXBackupStaleWorkspaceCleanupErrorUnsafeReservedEntry,
+            PXBackupStaleWorkspaceCleanupEntryField,
+            @"The cleanup tree contains an unsafe regular file");
+        return NO;
+    }
+    int descriptor = openat(parentDescriptor,
+                            name,
+                            O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC);
+    if (descriptor < 0) {
+        PXBackupStaleWorkspaceCleanupSetError(
+            error,
+            PXBackupStaleWorkspaceCleanupErrorEntryChanged,
+            PXBackupStaleWorkspaceCleanupEntryField,
+            @"A cleanup file changed before it could be opened");
+        return NO;
+    }
+    struct stat descriptorStat;
+    struct stat namespaceStat;
+    BOOL valid = fstat(descriptor, &descriptorStat) == 0 &&
+                 S_ISREG(descriptorStat.st_mode) &&
+                 descriptorStat.st_dev == state->workspaceDevice &&
+                 (descriptorStat.st_mode & (S_ISUID | S_ISGID)) == 0 &&
+                 descriptorStat.st_nlink == 1 &&
+                 PXBackupStaleWorkspaceCleanupStableFileMatches(observed,
+                                                         &descriptorStat) &&
+                 PXBackupStaleWorkspaceCleanupDescriptorHasCloseOnExec(descriptor) &&
+                 fstatat(parentDescriptor,
+                         name,
+                         &namespaceStat,
+                         AT_SYMLINK_NOFOLLOW) == 0 &&
+                 PXBackupStaleWorkspaceCleanupStableFileMatches(&namespaceStat,
+                                                         &descriptorStat);
+    if (!valid) {
+        close(descriptor);
+        PXBackupStaleWorkspaceCleanupSetError(
+            error,
+            PXBackupStaleWorkspaceCleanupErrorEntryChanged,
+            PXBackupStaleWorkspaceCleanupEntryField,
+            @"A cleanup file changed during identity validation");
+        return NO;
+    }
+    if (state->removedEntries == NSUIntegerMax) {
+        close(descriptor);
+        PXBackupStaleWorkspaceCleanupSetError(
+            error,
+            PXBackupStaleWorkspaceCleanupErrorLimitExceeded,
+            PXBackupStaleWorkspaceCleanupEntryField,
+            @"The cleanup removal count overflowed");
+        return NO;
+    }
+    char *quarantineName = NULL;
+    if (!PXBackupStaleWorkspaceCleanupCaptureEntry(
+            parentDescriptor,
+            name,
+            descriptor,
+            &descriptorStat,
+            PXBackupStaleWorkspaceCleanupCaptureTypeRegularFile,
+            state->workspaceDevice,
+            NO,
+            state->destructiveMutationOccurred || state->removedEntries > 0,
+            &quarantineName,
+            error)) {
+        close(descriptor);
+        return NO;
+    }
+    if (!PXBackupStaleWorkspaceCleanupCapturedBindingValid(
+            parentDescriptor,
+            quarantineName,
+            descriptor,
+            &descriptorStat,
+            PXBackupStaleWorkspaceCleanupCaptureTypeRegularFile,
+            state->workspaceDevice,
+            NO,
+            NULL)) {
+        free(quarantineName);
+        close(descriptor);
+        PXBackupStaleWorkspaceCleanupSetError(
+            error,
+            state->destructiveMutationOccurred || state->removedEntries > 0
+                ? PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete
+                : PXBackupStaleWorkspaceCleanupErrorEntryChanged,
+            PXBackupStaleWorkspaceCleanupEntryField,
+            @"A quarantined cleanup file changed before removal");
+        return NO;
+    }
+    if (unlinkat(parentDescriptor, quarantineName, 0) != 0) {
+        free(quarantineName);
+        close(descriptor);
+        PXBackupStaleWorkspaceCleanupSetError(
+            error,
+            state->destructiveMutationOccurred || state->removedEntries > 0
+                ? PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete
+                : PXBackupStaleWorkspaceCleanupErrorRemovalFailed,
+            PXBackupStaleWorkspaceCleanupEntryField,
+            @"A quarantined cleanup file could not be removed");
+        return NO;
+    }
+    state->destructiveMutationOccurred = YES;
+    struct stat unlinkedStat;
+    BOOL removed =
+        PXBackupStaleWorkspaceCleanupEntryIsAbsent(parentDescriptor, quarantineName) &&
+        fstat(descriptor, &unlinkedStat) == 0 &&
+        PXBackupStaleWorkspaceCleanupStatIdentityMatches(&descriptorStat,
+                                                  &unlinkedStat) &&
+        unlinkedStat.st_nlink == 0;
+    free(quarantineName);
+    close(descriptor);
+    if (!removed) {
+        PXBackupStaleWorkspaceCleanupSetError(
+            error,
+            PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete,
+            PXBackupStaleWorkspaceCleanupEntryField,
+            @"A cleanup file removal could not be proven");
+        return NO;
+    }
+    if (!PXBackupStaleWorkspaceCleanupStrictSync(parentDescriptor)) {
+        PXBackupStaleWorkspaceCleanupSetError(
+            error,
+            PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete,
+            PXBackupStaleWorkspaceCleanupDurabilityField,
+            @"A cleanup file removal could not be synchronized");
+        return NO;
+    }
+    state->removedEntries += 1U;
+    return YES;
+}
+
+static BOOL PXBackupStaleWorkspaceCleanupRemoveSubdirectory(
+    int parentDescriptor,
+    const char *name,
+    const struct stat *observed,
+    NSUInteger depth,
+    PXBackupStaleWorkspaceCleanupTraversalState *state,
+    NSError **error) {
+    if (!observed || !state || !S_ISDIR(observed->st_mode) ||
+        observed->st_dev != state->workspaceDevice ||
+        (observed->st_mode & (S_ISUID | S_ISGID)) != 0) {
+        PXBackupStaleWorkspaceCleanupSetError(
+            error,
+            PXBackupStaleWorkspaceCleanupErrorUnsafeReservedEntry,
+            PXBackupStaleWorkspaceCleanupEntryField,
+            @"The cleanup tree contains an unsafe directory");
+        return NO;
+    }
+    if (depth >= PXBackupStaleWorkspaceCleanupMaximumDepth) {
+        PXBackupStaleWorkspaceCleanupSetError(
+            error,
+            PXBackupStaleWorkspaceCleanupErrorLimitExceeded,
+            PXBackupStaleWorkspaceCleanupEntryField,
+            @"The cleanup tree exceeds the maximum depth");
+        return NO;
+    }
+    int descriptor = openat(parentDescriptor,
+                            name,
+                            O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
+    if (descriptor < 0) {
+        PXBackupStaleWorkspaceCleanupSetError(
+            error,
+            PXBackupStaleWorkspaceCleanupErrorEntryChanged,
+            PXBackupStaleWorkspaceCleanupEntryField,
+            @"A cleanup directory changed before it could be opened");
+        return NO;
+    }
+    struct stat descriptorStat;
+    BOOL bindingValid = fstat(descriptor, &descriptorStat) == 0 &&
+                        S_ISDIR(descriptorStat.st_mode) &&
+                        descriptorStat.st_dev == state->workspaceDevice &&
+                        (descriptorStat.st_mode & (S_ISUID | S_ISGID)) == 0 &&
+                        PXBackupStaleWorkspaceCleanupStatIdentityMatches(observed,
+                                                                 &descriptorStat) &&
+                        PXBackupStaleWorkspaceCleanupDescriptorHasCloseOnExec(descriptor);
+    if (!bindingValid) {
+        close(descriptor);
+        PXBackupStaleWorkspaceCleanupSetError(
+            error,
+            PXBackupStaleWorkspaceCleanupErrorEntryChanged,
+            PXBackupStaleWorkspaceCleanupEntryField,
+            @"A cleanup directory changed during identity validation");
+        return NO;
+    }
+    if (!PXBackupStaleWorkspaceCleanupRemoveDirectoryContents(descriptor,
+                                                       &descriptorStat,
+                                                       depth + 1U,
+                                                       state,
+                                                       error)) {
+        close(descriptor);
+        return NO;
+    }
+    BOOL empty = NO;
+    if (!PXBackupStaleWorkspaceCleanupDirectoryIsEmpty(descriptor, &empty, error) ||
+        !empty) {
+        close(descriptor);
+        if (error && !*error) {
+            PXBackupStaleWorkspaceCleanupSetError(
+                error,
+                PXBackupStaleWorkspaceCleanupErrorEntryChanged,
+                PXBackupStaleWorkspaceCleanupEntryField,
+                @"A cleanup directory was repopulated during traversal");
+        }
+        return NO;
+    }
+    if (!PXBackupStaleWorkspaceCleanupStrictSync(descriptor)) {
+        close(descriptor);
+        PXBackupStaleWorkspaceCleanupSetError(
+            error,
+            state->destructiveMutationOccurred || state->removedEntries > 0
+                ? PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete
+                : PXBackupStaleWorkspaceCleanupErrorDurabilityFailed,
+            PXBackupStaleWorkspaceCleanupDurabilityField,
+            @"A cleanup directory could not be synchronized");
+        return NO;
+    }
+    struct stat namespaceStat;
+    struct stat currentDescriptorStat;
+    BOOL stable = fstatat(parentDescriptor,
+                          name,
+                          &namespaceStat,
+                          AT_SYMLINK_NOFOLLOW) == 0 &&
+                  fstat(descriptor, &currentDescriptorStat) == 0 &&
+                  S_ISDIR(namespaceStat.st_mode) &&
+                  S_ISDIR(currentDescriptorStat.st_mode) &&
+                  namespaceStat.st_dev == state->workspaceDevice &&
+                  currentDescriptorStat.st_dev == state->workspaceDevice &&
+                  (namespaceStat.st_mode & (S_ISUID | S_ISGID)) == 0 &&
+                  (currentDescriptorStat.st_mode & (S_ISUID | S_ISGID)) == 0 &&
+                  PXBackupStaleWorkspaceCleanupStatIdentityMatches(&namespaceStat,
+                                                            &descriptorStat) &&
+                  PXBackupStaleWorkspaceCleanupStatIdentityMatches(&currentDescriptorStat,
+                                                            &descriptorStat);
+    if (!stable) {
+        close(descriptor);
+        PXBackupStaleWorkspaceCleanupSetError(
+            error,
+            state->destructiveMutationOccurred || state->removedEntries > 0
+                ? PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete
+                : PXBackupStaleWorkspaceCleanupErrorEntryChanged,
+            PXBackupStaleWorkspaceCleanupEntryField,
+            @"A cleanup directory changed before atomic capture");
+        return NO;
+    }
+    if (state->removedEntries == NSUIntegerMax) {
+        close(descriptor);
+        PXBackupStaleWorkspaceCleanupSetError(
+            error,
+            PXBackupStaleWorkspaceCleanupErrorLimitExceeded,
+            PXBackupStaleWorkspaceCleanupEntryField,
+            @"The cleanup removal count overflowed");
+        return NO;
+    }
+    char *quarantineName = NULL;
+    if (!PXBackupStaleWorkspaceCleanupCaptureEntry(
+            parentDescriptor,
+            name,
+            descriptor,
+            &descriptorStat,
+            PXBackupStaleWorkspaceCleanupCaptureTypeDirectory,
+            state->workspaceDevice,
+            NO,
+            state->destructiveMutationOccurred || state->removedEntries > 0,
+            &quarantineName,
+            error)) {
+        close(descriptor);
+        return NO;
+    }
+    BOOL capturedEmpty = NO;
+    NSError *capturedEmptyError = nil;
+    BOOL capturedValid =
+        PXBackupStaleWorkspaceCleanupCapturedBindingValid(
+            parentDescriptor,
+            quarantineName,
+            descriptor,
+            &descriptorStat,
+            PXBackupStaleWorkspaceCleanupCaptureTypeDirectory,
+            state->workspaceDevice,
+            NO,
+            NULL) &&
+        PXBackupStaleWorkspaceCleanupDirectoryIsEmpty(descriptor,
+                                               &capturedEmpty,
+                                               &capturedEmptyError) &&
+        capturedEmpty;
+    if (!capturedValid) {
+        free(quarantineName);
+        close(descriptor);
+        if (error) {
+            *error = capturedEmptyError;
+            if (!*error) {
+                PXBackupStaleWorkspaceCleanupSetError(
+                    error,
+                    state->destructiveMutationOccurred || state->removedEntries > 0
+                        ? PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete
+                        : PXBackupStaleWorkspaceCleanupErrorEntryChanged,
+                    PXBackupStaleWorkspaceCleanupEntryField,
+                    @"A quarantined cleanup directory changed before removal");
+            }
+        }
+        return NO;
+    }
+    if (unlinkat(parentDescriptor, quarantineName, AT_REMOVEDIR) != 0) {
+        free(quarantineName);
+        close(descriptor);
+        PXBackupStaleWorkspaceCleanupSetError(
+            error,
+            state->destructiveMutationOccurred || state->removedEntries > 0
+                ? PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete
+                : PXBackupStaleWorkspaceCleanupErrorRemovalFailed,
+            PXBackupStaleWorkspaceCleanupEntryField,
+            @"A quarantined cleanup directory could not be removed");
+        return NO;
+    }
+    state->destructiveMutationOccurred = YES;
+    BOOL removed =
+        PXBackupStaleWorkspaceCleanupEntryIsAbsent(parentDescriptor, quarantineName);
+    free(quarantineName);
+    close(descriptor);
+    if (!removed) {
+        PXBackupStaleWorkspaceCleanupSetError(
+            error,
+            PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete,
+            PXBackupStaleWorkspaceCleanupEntryField,
+            @"A cleanup directory removal could not be proven");
+        return NO;
+    }
+    if (!PXBackupStaleWorkspaceCleanupStrictSync(parentDescriptor)) {
+        PXBackupStaleWorkspaceCleanupSetError(
+            error,
+            PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete,
+            PXBackupStaleWorkspaceCleanupDurabilityField,
+            @"A cleanup directory removal could not be synchronized");
+        return NO;
+    }
+    state->removedEntries += 1U;
+    return YES;
+}
+
+static BOOL PXBackupStaleWorkspaceCleanupRemoveDirectoryContents(
+    int descriptor,
+    const struct stat *directoryIdentity,
+    NSUInteger depth,
+    PXBackupStaleWorkspaceCleanupTraversalState *state,
+    NSError **error) {
+    if (descriptor < 0 || !directoryIdentity || !state ||
+        depth > PXBackupStaleWorkspaceCleanupMaximumDepth) {
+        PXBackupStaleWorkspaceCleanupSetError(
+            error,
+            PXBackupStaleWorkspaceCleanupErrorLimitExceeded,
+            PXBackupStaleWorkspaceCleanupEntryField,
+            @"The cleanup traversal exceeded fixed limits");
+        return NO;
+    }
+    struct stat currentDirectory;
+    if (fstat(descriptor, &currentDirectory) != 0 ||
+        !S_ISDIR(currentDirectory.st_mode) ||
+        currentDirectory.st_dev != state->workspaceDevice ||
+        (currentDirectory.st_mode & (S_ISUID | S_ISGID)) != 0 ||
+        !PXBackupStaleWorkspaceCleanupStatIdentityMatches(directoryIdentity,
+                                                   &currentDirectory) ||
+        !PXBackupStaleWorkspaceCleanupDescriptorHasCloseOnExec(descriptor)) {
+        PXBackupStaleWorkspaceCleanupSetError(
+            error,
+            PXBackupStaleWorkspaceCleanupErrorEntryChanged,
+            PXBackupStaleWorkspaceCleanupEntryField,
+            @"A cleanup directory identity changed during traversal");
+        return NO;
+    }
+    NSArray<NSData *> *names = nil;
+    if (!PXBackupStaleWorkspaceCleanupScanEntryNames(descriptor,
+                                              state,
+                                              &names,
+                                              error)) return NO;
+    for (NSData *nameData in names) {
+        char *name = PXBackupStaleWorkspaceCleanupCopyCString(nameData);
+        if (!name) {
+            PXBackupStaleWorkspaceCleanupSetError(
+                error,
+                PXBackupStaleWorkspaceCleanupErrorLimitExceeded,
+                PXBackupStaleWorkspaceCleanupEntryField,
+                @"A cleanup entry name could not be represented safely");
+            return NO;
+        }
+        struct stat observed;
+        BOOL observedValid = fstatat(descriptor,
+                                     name,
+                                     &observed,
+                                     AT_SYMLINK_NOFOLLOW) == 0;
+        if (!observedValid) {
+            free(name);
+            PXBackupStaleWorkspaceCleanupSetError(
+                error,
+                PXBackupStaleWorkspaceCleanupErrorEntryChanged,
+                PXBackupStaleWorkspaceCleanupEntryField,
+                @"A cleanup entry changed before inspection");
+            return NO;
+        }
+        BOOL removed = NO;
+        if (S_ISREG(observed.st_mode)) {
+            removed = PXBackupStaleWorkspaceCleanupRemoveRegularFile(descriptor,
+                                                              name,
+                                                              &observed,
+                                                              state,
+                                                              error);
+        } else if (S_ISDIR(observed.st_mode)) {
+            removed = PXBackupStaleWorkspaceCleanupRemoveSubdirectory(descriptor,
+                                                               name,
+                                                               &observed,
+                                                               depth,
+                                                               state,
+                                                               error);
+        } else {
+            PXBackupStaleWorkspaceCleanupSetError(
+                error,
+                PXBackupStaleWorkspaceCleanupErrorUnsafeReservedEntry,
+                PXBackupStaleWorkspaceCleanupEntryField,
+                @"The cleanup tree contains an unsupported entry type");
+        }
+        free(name);
+        if (!removed) return NO;
+    }
+    BOOL empty = NO;
+    if (!PXBackupStaleWorkspaceCleanupDirectoryIsEmpty(descriptor, &empty, error)) {
+        return NO;
+    }
+    if (!empty) {
+        PXBackupStaleWorkspaceCleanupSetError(
+            error,
+            PXBackupStaleWorkspaceCleanupErrorEntryChanged,
+            PXBackupStaleWorkspaceCleanupEntryField,
+            @"The cleanup directory changed during traversal");
+        return NO;
+    }
+    return YES;
+}
+
+
+typedef struct {
+    char *name;
+    int descriptor;
+    struct stat identity;
+} PXBackupStaleWorkspaceCandidate;
+
+static BOOL PXBackupStaleWorkspaceCleanupBytesHavePrefix(NSData *data,
+                                                          const char *prefix,
+                                                          size_t prefixLength) {
+    return [data isKindOfClass:[NSData class]] && data.length >= prefixLength &&
+        memcmp(data.bytes, prefix, prefixLength) == 0;
+}
+
+static BOOL PXBackupStaleWorkspaceCleanupExactPartialName(NSData *data) {
+    const size_t prefixLength =
+        sizeof(PXBackupStaleWorkspaceCleanupPartialPrefix) - 1U;
+    if (![data isKindOfClass:[NSData class]] ||
+        data.length != prefixLength + 6U ||
+        !PXBackupStaleWorkspaceCleanupBytesHavePrefix(
+            data,
+            PXBackupStaleWorkspaceCleanupPartialPrefix,
+            prefixLength)) return NO;
+    const unsigned char *bytes = data.bytes;
+    for (NSUInteger index = (NSUInteger)prefixLength; index < data.length; index++) {
+        unsigned char byte = bytes[index];
+        BOOL alphanumeric = (byte >= '0' && byte <= '9') ||
+            (byte >= 'A' && byte <= 'Z') ||
+            (byte >= 'a' && byte <= 'z');
+        if (!alphanumeric) return NO;
+    }
+    return YES;
+}
+
+static BOOL PXBackupStaleWorkspaceCleanupExactQuarantineName(NSData *data) {
+    const size_t prefixLength =
+        sizeof(PXBackupStaleWorkspaceCleanupQuarantinePrefix) - 1U;
+    if (![data isKindOfClass:[NSData class]] ||
+        data.length != prefixLength + 32U ||
+        !PXBackupStaleWorkspaceCleanupBytesHavePrefix(
+            data,
+            PXBackupStaleWorkspaceCleanupQuarantinePrefix,
+            prefixLength)) return NO;
+    const unsigned char *bytes = data.bytes;
+    for (NSUInteger index = (NSUInteger)prefixLength; index < data.length; index++) {
+        unsigned char byte = bytes[index];
+        if (!((byte >= '0' && byte <= '9') ||
+              (byte >= 'a' && byte <= 'f'))) return NO;
+    }
+    return YES;
+}
+
+static BOOL PXBackupStaleWorkspaceCleanupReservedPrefix(NSData *data) {
+    return PXBackupStaleWorkspaceCleanupBytesHavePrefix(
+               data,
+               PXBackupStaleWorkspaceCleanupPartialPrefix,
+               sizeof(PXBackupStaleWorkspaceCleanupPartialPrefix) - 1U) ||
+        PXBackupStaleWorkspaceCleanupBytesHavePrefix(
+               data,
+               PXBackupStaleWorkspaceCleanupQuarantinePrefix,
+               sizeof(PXBackupStaleWorkspaceCleanupQuarantinePrefix) - 1U);
+}
+
+static NSComparisonResult PXBackupStaleWorkspaceCleanupCompareData(NSData *left,
+                                                                    NSData *right) {
+    NSUInteger common = MIN(left.length, right.length);
+    int comparison = common == 0 ? 0 : memcmp(left.bytes, right.bytes, common);
+    if (comparison < 0) return NSOrderedAscending;
+    if (comparison > 0) return NSOrderedDescending;
+    if (left.length < right.length) return NSOrderedAscending;
+    if (left.length > right.length) return NSOrderedDescending;
+    return NSOrderedSame;
+}
+
+static void PXBackupStaleWorkspaceCleanupCloseCandidates(
+    PXBackupStaleWorkspaceCandidate *candidates,
+    NSUInteger count) {
+    if (!candidates) return;
+    for (NSUInteger index = 0; index < count; index++) {
+        if (candidates[index].descriptor >= 0) {
+            close(candidates[index].descriptor);
+            candidates[index].descriptor = -1;
+        }
+        if (candidates[index].name) {
+            free(candidates[index].name);
+            candidates[index].name = NULL;
+        }
+    }
+    free(candidates);
+}
+
+static NSError *PXBackupStaleWorkspaceCleanupErrorOrMissing(NSError *candidate) {
+    return candidate ?: [NSError
+        errorWithDomain:PXBackupStaleWorkspaceCleanupErrorDomain
+                   code:PXBackupStaleWorkspaceCleanupErrorMissingError
+               userInfo:@{
+                   NSLocalizedDescriptionKey:
+                       @"The stale-cleanup operation failed without an error",
+                   PXBackupStaleWorkspaceCleanupErrorFieldPathKey:
+                       PXBackupStaleWorkspaceCleanupField,
+               }];
+}
+
+@interface PXBackupStaleWorkspaceCleanup () {
+    PXBackupBundleLock *_bundleLock;
+    NSString *_canonicalBundleDirectoryPath;
+    NSString *_bundleIdentifier;
+    int _bundleDescriptor;
+    struct stat _bundleIdentity;
+    BOOL _cleanupAttempted;
+    BOOL _cleanupCompleted;
+    BOOL _cleanupFailed;
+    NSUInteger _cleanedWorkspaceCount;
+    NSUInteger _removedEntryCount;
+}
+
+- (instancetype)initWithBundleLock:(PXBackupBundleLock *)bundleLock
+             canonicalBundlePath:(NSString *)canonicalBundlePath
+                bundleIdentifier:(NSString *)bundleIdentifier
+                bundleDescriptor:(int)bundleDescriptor
+                  bundleIdentity:(const struct stat *)bundleIdentity;
+
+@end
+
+@implementation PXBackupStaleWorkspaceCleanup
+
++ (nullable instancetype)cleanupForBundleLock:(PXBackupBundleLock *)bundleLock
+                                        error:(NSError **)error {
+    if (error) *error = nil;
+    if (![bundleLock isMemberOfClass:[PXBackupBundleLock class]]) {
+        PXBackupStaleWorkspaceCleanupSetError(
+            error,
+            PXBackupStaleWorkspaceCleanupErrorInvalidInput,
+            PXBackupStaleWorkspaceCleanupLockField,
+            @"The stale-cleanup bundle lock is invalid");
+        return nil;
+    }
+    NSError *lockError = nil;
+    if (![bundleLock validateOwnershipWithError:&lockError]) {
+        (void)lockError;
+        PXBackupStaleWorkspaceCleanupSetError(
+            error,
+            PXBackupStaleWorkspaceCleanupErrorLockValidationFailed,
+            PXBackupStaleWorkspaceCleanupLockField,
+            @"The stale-cleanup bundle lock is not owned");
+        return nil;
+    }
+    NSString *path = bundleLock.canonicalBundleDirectoryPath;
+    NSString *bundleIdentifier = bundleLock.bundleIdentifier;
+    NSData *pathData = [path dataUsingEncoding:NSUTF8StringEncoding
+                          allowLossyConversion:NO];
+    NSString *pathRoundTrip = [pathData isKindOfClass:[NSData class]]
+        ? [[NSString alloc] initWithData:pathData encoding:NSUTF8StringEncoding]
+        : nil;
+    NSString *expectedPath = [bundleLock.canonicalBackupRootPath
+        stringByAppendingPathComponent:bundleIdentifier];
+    if (![path isKindOfClass:[NSString class]] || ![path hasPrefix:@"/"] ||
+        PXBackupStaleWorkspaceCleanupStringContainsNUL(path) ||
+        ![pathData isKindOfClass:[NSData class]] || pathData.length == 0 ||
+        pathData.length > PXBackupStaleWorkspaceCleanupMaximumWorkspacePathBytes ||
+        ![pathRoundTrip isEqualToString:path] ||
+        !PXBackupStaleWorkspaceCleanupValidateComponentString(bundleIdentifier, NULL) ||
+        ![path isEqualToString:expectedPath]) {
+        PXBackupStaleWorkspaceCleanupSetError(
+            error,
+            PXBackupStaleWorkspaceCleanupErrorInvalidInput,
+            PXBackupStaleWorkspaceCleanupParentField,
+            @"The stale-cleanup bundle directory is invalid");
+        return nil;
+    }
+    char *pathBytes = PXBackupStaleWorkspaceCleanupCopyCString(pathData);
+    if (!pathBytes) {
+        PXBackupStaleWorkspaceCleanupSetError(
+            error,
+            PXBackupStaleWorkspaceCleanupErrorInternalInvariantFailed,
+            PXBackupStaleWorkspaceCleanupParentField,
+            @"The stale-cleanup bundle directory could not be retained");
+        return nil;
+    }
+    struct stat namespaceStat;
+    int descriptor = -1;
+    if (lstat(pathBytes, &namespaceStat) != 0 ||
+        !S_ISDIR(namespaceStat.st_mode) ||
+        (namespaceStat.st_mode & (S_ISUID | S_ISGID)) != 0) {
+        free(pathBytes);
+        PXBackupStaleWorkspaceCleanupSetError(
+            error,
+            PXBackupStaleWorkspaceCleanupErrorParentInspectionFailed,
+            PXBackupStaleWorkspaceCleanupParentField,
+            @"The stale-cleanup bundle directory is unsafe");
+        return nil;
+    }
+    descriptor = open(pathBytes,
+                      O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
+    free(pathBytes);
+    struct stat descriptorStat;
+    if (descriptor < 0 ||
+        !PXBackupStaleWorkspaceCleanupDescriptorHasCloseOnExec(descriptor) ||
+        fstat(descriptor, &descriptorStat) != 0 ||
+        !PXBackupStaleWorkspaceCleanupStatIdentityMatches(&namespaceStat,
+                                                          &descriptorStat)) {
+        if (descriptor >= 0) close(descriptor);
+        PXBackupStaleWorkspaceCleanupSetError(
+            error,
+            PXBackupStaleWorkspaceCleanupErrorFilesystemChanged,
+            PXBackupStaleWorkspaceCleanupParentField,
+            @"The stale-cleanup bundle directory identity changed");
+        return nil;
+    }
+    NSError *finalLockError = nil;
+    if (![bundleLock validateOwnershipWithError:&finalLockError]) {
+        (void)finalLockError;
+        close(descriptor);
+        PXBackupStaleWorkspaceCleanupSetError(
+            error,
+            PXBackupStaleWorkspaceCleanupErrorLockValidationFailed,
+            PXBackupStaleWorkspaceCleanupLockField,
+            @"The stale-cleanup bundle lock changed during binding");
+        return nil;
+    }
+    PXBackupStaleWorkspaceCleanup *result =
+        [[PXBackupStaleWorkspaceCleanup alloc]
+            initWithBundleLock:bundleLock
+           canonicalBundlePath:path
+              bundleIdentifier:bundleIdentifier
+              bundleDescriptor:descriptor
+                bundleIdentity:&descriptorStat];
+    if (!result) {
+        close(descriptor);
+        PXBackupStaleWorkspaceCleanupSetError(
+            error,
+            PXBackupStaleWorkspaceCleanupErrorInternalInvariantFailed,
+            PXBackupStaleWorkspaceCleanupField,
+            @"The stale-cleanup authority could not be created");
+        return nil;
+    }
+    if (error) *error = nil;
+    return result;
+}
+
+- (instancetype)initWithBundleLock:(PXBackupBundleLock *)bundleLock
+             canonicalBundlePath:(NSString *)canonicalBundlePath
+                bundleIdentifier:(NSString *)bundleIdentifier
+                bundleDescriptor:(int)bundleDescriptor
+                  bundleIdentity:(const struct stat *)bundleIdentity {
+    self = [super init];
+    if (self) {
+        _bundleLock = bundleLock;
+        _canonicalBundleDirectoryPath = [canonicalBundlePath copy];
+        _bundleIdentifier = [bundleIdentifier copy];
+        _bundleDescriptor = bundleDescriptor;
+        _bundleIdentity = *bundleIdentity;
+    }
+    return self;
+}
+
+- (NSString *)canonicalBundleDirectoryPath {
+    return _canonicalBundleDirectoryPath;
+}
+
+- (BOOL)cleanupAttempted {
+    return _cleanupAttempted;
+}
+
+- (NSUInteger)cleanedWorkspaceCount {
+    return _cleanedWorkspaceCount;
+}
+
+- (NSUInteger)removedEntryCount {
+    return _removedEntryCount;
+}
+
+- (BOOL)validateIdentityWithError:(NSError **)error {
+    if (error) *error = nil;
+    if (_cleanupFailed || (_cleanupAttempted && !_cleanupCompleted)) {
+        PXBackupStaleWorkspaceCleanupSetError(
+            error,
+            PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete,
+            PXBackupStaleWorkspaceCleanupField,
+            @"The stale-cleanup operation did not finish safely");
+        return NO;
+    }
+    if (_bundleDescriptor < 0 ||
+        ![_bundleLock isMemberOfClass:[PXBackupBundleLock class]] ||
+        ![_canonicalBundleDirectoryPath isKindOfClass:[NSString class]] ||
+        ![_bundleIdentifier isKindOfClass:[NSString class]]) {
+        PXBackupStaleWorkspaceCleanupSetError(
+            error,
+            PXBackupStaleWorkspaceCleanupErrorInternalInvariantFailed,
+            PXBackupStaleWorkspaceCleanupField,
+            @"The stale-cleanup retained state is invalid");
+        return NO;
+    }
+    NSError *lockError = nil;
+    if (![_bundleLock validateOwnershipWithError:&lockError] ||
+        !PXBackupStaleWorkspaceCleanupPathMatchesDescriptor(
+            _canonicalBundleDirectoryPath,
+            _bundleDescriptor,
+            &_bundleIdentity,
+            NO,
+            NULL)) {
+        (void)lockError;
+        PXBackupStaleWorkspaceCleanupSetError(
+            error,
+            PXBackupStaleWorkspaceCleanupErrorFilesystemChanged,
+            PXBackupStaleWorkspaceCleanupParentField,
+            @"The stale-cleanup retained authority changed");
+        return NO;
+    }
+    if (_cleanupCompleted) {
+        PXBackupStaleWorkspaceCleanupTraversalState validationState = {0};
+        validationState.workspaceDevice = _bundleIdentity.st_dev;
+        NSArray<NSData *> *names = nil;
+        NSError *scanError = nil;
+        if (!PXBackupStaleWorkspaceCleanupScanEntryNames(
+                _bundleDescriptor,
+                &validationState,
+                &names,
+                &scanError)) {
+            if (error) *error = PXBackupStaleWorkspaceCleanupErrorOrMissing(scanError);
+            return NO;
+        }
+        for (NSData *nameData in names) {
+            if (PXBackupStaleWorkspaceCleanupReservedPrefix(nameData)) {
+                PXBackupStaleWorkspaceCleanupSetError(
+                    error,
+                    PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete,
+                    PXBackupStaleWorkspaceCleanupEntryField,
+                    @"Reserved stale-cleanup evidence remains after cleanup");
+                return NO;
+            }
+        }
+    }
+    if (error) *error = nil;
+    return YES;
+}
+
+- (BOOL)removeStaleWorkspacesWithError:(NSError **)error {
+    if (error) *error = nil;
+    if (_cleanupAttempted) {
+        PXBackupStaleWorkspaceCleanupSetError(
+            error,
+            PXBackupStaleWorkspaceCleanupErrorAlreadyPerformed,
+            PXBackupStaleWorkspaceCleanupField,
+            @"The stale-cleanup operation is one-shot");
+        return NO;
+    }
+    NSError *identityError = nil;
+    if (![self validateIdentityWithError:&identityError]) {
+        _cleanupAttempted = YES;
+        _cleanupFailed = YES;
+        if (error) *error = PXBackupStaleWorkspaceCleanupErrorOrMissing(identityError);
+        return NO;
+    }
+    _cleanupAttempted = YES;
+
+    PXBackupStaleWorkspaceCleanupTraversalState state = {0};
+    state.workspaceDevice = _bundleIdentity.st_dev;
+    NSArray<NSData *> *allNames = nil;
+    NSError *scanError = nil;
+    if (!PXBackupStaleWorkspaceCleanupScanEntryNames(
+            _bundleDescriptor,
+            &state,
+            &allNames,
+            &scanError)) {
+        _cleanupFailed = YES;
+        if (error) *error = PXBackupStaleWorkspaceCleanupErrorOrMissing(scanError);
+        return NO;
+    }
+    NSArray<NSData *> *sortedNames = [allNames sortedArrayUsingComparator:
+        ^NSComparisonResult(NSData *left, NSData *right) {
+            return PXBackupStaleWorkspaceCleanupCompareData(left, right);
+        }];
+    PXBackupStaleWorkspaceCandidate *candidates = calloc(
+        PXBackupStaleWorkspaceCleanupMaximumTopLevelCandidates,
+        sizeof(PXBackupStaleWorkspaceCandidate));
+    if (!candidates) {
+        _cleanupFailed = YES;
+        PXBackupStaleWorkspaceCleanupSetError(
+            error,
+            PXBackupStaleWorkspaceCleanupErrorLimitExceeded,
+            PXBackupStaleWorkspaceCleanupEntryField,
+            @"The stale-cleanup candidate list could not be allocated");
+        return NO;
+    }
+    for (NSUInteger index = 0;
+         index < PXBackupStaleWorkspaceCleanupMaximumTopLevelCandidates;
+         index++) {
+        candidates[index].descriptor = -1;
+    }
+    NSUInteger candidateCount = 0U;
+    BOOL preflightValid = YES;
+    NSError *preflightError = nil;
+    for (NSData *nameData in sortedNames) {
+        BOOL exactPartial = PXBackupStaleWorkspaceCleanupExactPartialName(nameData);
+        BOOL exactQuarantine =
+            PXBackupStaleWorkspaceCleanupExactQuarantineName(nameData);
+        BOOL reservedPrefix =
+            PXBackupStaleWorkspaceCleanupReservedPrefix(nameData);
+        if (reservedPrefix && !exactPartial && !exactQuarantine) {
+            PXBackupStaleWorkspaceCleanupSetError(
+                &preflightError,
+                PXBackupStaleWorkspaceCleanupErrorReservedNameInvalid,
+                PXBackupStaleWorkspaceCleanupEntryField,
+                @"A reserved stale-workspace name is malformed");
+            preflightValid = NO;
+            break;
+        }
+        if (!exactPartial && !exactQuarantine) continue;
+        if (candidateCount >= PXBackupStaleWorkspaceCleanupMaximumTopLevelCandidates) {
+            PXBackupStaleWorkspaceCleanupSetError(
+                &preflightError,
+                PXBackupStaleWorkspaceCleanupErrorLimitExceeded,
+                PXBackupStaleWorkspaceCleanupEntryField,
+                @"The stale-workspace candidate limit was exceeded");
+            preflightValid = NO;
+            break;
+        }
+        char *nameBytes = PXBackupStaleWorkspaceCleanupCopyCString(nameData);
+        struct stat namespaceStat;
+        if (!nameBytes ||
+            fstatat(_bundleDescriptor,
+                    nameBytes,
+                    &namespaceStat,
+                    AT_SYMLINK_NOFOLLOW) != 0 ||
+            !S_ISDIR(namespaceStat.st_mode) ||
+            (namespaceStat.st_mode & 07777) != 0700 ||
+            (namespaceStat.st_mode & (S_ISUID | S_ISGID)) != 0 ||
+            namespaceStat.st_dev != _bundleIdentity.st_dev) {
+            free(nameBytes);
+            PXBackupStaleWorkspaceCleanupSetError(
+                &preflightError,
+                PXBackupStaleWorkspaceCleanupErrorUnsafeReservedEntry,
+                PXBackupStaleWorkspaceCleanupEntryField,
+                @"A reserved stale-workspace entry is unsafe");
+            preflightValid = NO;
+            break;
+        }
+        int descriptor = openat(_bundleDescriptor,
+                                nameBytes,
+                                O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
+        struct stat descriptorStat;
+        if (descriptor < 0 ||
+            !PXBackupStaleWorkspaceCleanupDescriptorHasCloseOnExec(descriptor) ||
+            fstat(descriptor, &descriptorStat) != 0 ||
+            !PXBackupStaleWorkspaceCleanupStatIdentityMatches(&namespaceStat,
+                                                              &descriptorStat) ||
+            (descriptorStat.st_mode & 07777) != 0700) {
+            if (descriptor >= 0) close(descriptor);
+            free(nameBytes);
+            PXBackupStaleWorkspaceCleanupSetError(
+                &preflightError,
+                PXBackupStaleWorkspaceCleanupErrorEntryChanged,
+                PXBackupStaleWorkspaceCleanupEntryField,
+                @"A reserved stale-workspace entry changed during preflight");
+            preflightValid = NO;
+            break;
+        }
+        candidates[candidateCount].name = nameBytes;
+        candidates[candidateCount].descriptor = descriptor;
+        candidates[candidateCount].identity = descriptorStat;
+        candidateCount += 1U;
+    }
+    if (!preflightValid) {
+        PXBackupStaleWorkspaceCleanupCloseCandidates(candidates, candidateCount);
+        _cleanupFailed = YES;
+        if (error) *error = PXBackupStaleWorkspaceCleanupErrorOrMissing(preflightError);
+        return NO;
+    }
+
+    for (NSUInteger index = 0; index < candidateCount; index++) {
+        PXBackupStaleWorkspaceCandidate *candidate = &candidates[index];
+        NSError *operationError = nil;
+        NSError *candidateLockError = nil;
+        BOOL validBefore = [_bundleLock validateOwnershipWithError:&candidateLockError] &&
+            PXBackupStaleWorkspaceCleanupPathMatchesDescriptor(
+                _canonicalBundleDirectoryPath,
+                _bundleDescriptor,
+                &_bundleIdentity,
+                NO,
+                NULL) &&
+            PXBackupStaleWorkspaceCleanupDirectoryBindingValid(
+                _bundleDescriptor,
+                candidate->name,
+                candidate->descriptor,
+                &candidate->identity,
+                _bundleIdentity.st_dev,
+                YES,
+                NULL);
+        if (!validBefore) {
+            if (!operationError) {
+                PXBackupStaleWorkspaceCleanupSetError(
+                    &operationError,
+                    PXBackupStaleWorkspaceCleanupErrorEntryChanged,
+                    PXBackupStaleWorkspaceCleanupEntryField,
+                    @"A stale-workspace authority changed before cleanup");
+            }
+            _cleanupFailed = YES;
+            _removedEntryCount = state.removedEntries;
+            PXBackupStaleWorkspaceCleanupCloseCandidates(candidates, candidateCount);
+            if (error) *error = PXBackupStaleWorkspaceCleanupErrorOrMissing(operationError);
+            return NO;
+        }
+        if (!PXBackupStaleWorkspaceCleanupRemoveDirectoryContents(
+                candidate->descriptor,
+                &candidate->identity,
+                0U,
+                &state,
+                &operationError)) {
+            _cleanupFailed = YES;
+            _removedEntryCount = state.removedEntries;
+            PXBackupStaleWorkspaceCleanupCloseCandidates(candidates, candidateCount);
+            if (error) *error = PXBackupStaleWorkspaceCleanupErrorOrMissing(operationError);
+            return NO;
+        }
+        BOOL empty = NO;
+        if (!PXBackupStaleWorkspaceCleanupDirectoryIsEmpty(
+                candidate->descriptor,
+                &empty,
+                &operationError) ||
+            !empty ||
+            !PXBackupStaleWorkspaceCleanupStrictSync(candidate->descriptor)) {
+            if (!operationError) {
+                PXBackupStaleWorkspaceCleanupSetError(
+                    &operationError,
+                    state.removedEntries > 0
+                        ? PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete
+                        : PXBackupStaleWorkspaceCleanupErrorDurabilityFailed,
+                    PXBackupStaleWorkspaceCleanupDurabilityField,
+                    @"A stale workspace could not be synchronized before capture");
+            }
+            _cleanupFailed = YES;
+            _removedEntryCount = state.removedEntries;
+            PXBackupStaleWorkspaceCleanupCloseCandidates(candidates, candidateCount);
+            if (error) *error = PXBackupStaleWorkspaceCleanupErrorOrMissing(operationError);
+            return NO;
+        }
+        char *quarantineName = NULL;
+        if (!PXBackupStaleWorkspaceCleanupCaptureEntry(
+                _bundleDescriptor,
+                candidate->name,
+                candidate->descriptor,
+                &candidate->identity,
+                PXBackupStaleWorkspaceCleanupCaptureTypeDirectory,
+                _bundleIdentity.st_dev,
+                YES,
+                state.destructiveMutationOccurred || state.removedEntries > 0,
+                &quarantineName,
+                &operationError)) {
+            _cleanupFailed = YES;
+            _removedEntryCount = state.removedEntries;
+            PXBackupStaleWorkspaceCleanupCloseCandidates(candidates, candidateCount);
+            if (error) *error = PXBackupStaleWorkspaceCleanupErrorOrMissing(operationError);
+            return NO;
+        }
+        BOOL capturedEmpty = NO;
+        BOOL capturedValid =
+            PXBackupStaleWorkspaceCleanupCapturedBindingValid(
+                _bundleDescriptor,
+                quarantineName,
+                candidate->descriptor,
+                &candidate->identity,
+                PXBackupStaleWorkspaceCleanupCaptureTypeDirectory,
+                _bundleIdentity.st_dev,
+                YES,
+                NULL) &&
+            PXBackupStaleWorkspaceCleanupDirectoryIsEmpty(
+                candidate->descriptor,
+                &capturedEmpty,
+                &operationError) &&
+            capturedEmpty;
+        if (!capturedValid ||
+            unlinkat(_bundleDescriptor, quarantineName, AT_REMOVEDIR) != 0) {
+            free(quarantineName);
+            _cleanupFailed = YES;
+            _removedEntryCount = state.removedEntries;
+            if (!operationError) {
+                PXBackupStaleWorkspaceCleanupSetError(
+                    &operationError,
+                    PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete,
+                    PXBackupStaleWorkspaceCleanupEntryField,
+                    @"A captured stale workspace could not be removed safely");
+            }
+            PXBackupStaleWorkspaceCleanupCloseCandidates(candidates, candidateCount);
+            if (error) *error = PXBackupStaleWorkspaceCleanupErrorOrMissing(operationError);
+            return NO;
+        }
+        state.destructiveMutationOccurred = YES;
+        BOOL removed =
+            PXBackupStaleWorkspaceCleanupEntryIsAbsent(_bundleDescriptor,
+                                                       quarantineName) &&
+            PXBackupStaleWorkspaceCleanupEntryIsAbsent(_bundleDescriptor,
+                                                       candidate->name) &&
+            PXBackupStaleWorkspaceCleanupStrictSync(_bundleDescriptor);
+        free(quarantineName);
+        if (!removed || state.removedEntries == NSUIntegerMax ||
+            _cleanedWorkspaceCount == NSUIntegerMax) {
+            _cleanupFailed = YES;
+            _removedEntryCount = state.removedEntries;
+            PXBackupStaleWorkspaceCleanupSetError(
+                &operationError,
+                PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete,
+                PXBackupStaleWorkspaceCleanupDurabilityField,
+                @"A stale workspace removal could not be proven durable");
+            PXBackupStaleWorkspaceCleanupCloseCandidates(candidates, candidateCount);
+            if (error) *error = PXBackupStaleWorkspaceCleanupErrorOrMissing(operationError);
+            return NO;
+        }
+        state.removedEntries += 1U;
+        _cleanedWorkspaceCount += 1U;
+        close(candidate->descriptor);
+        candidate->descriptor = -1;
+    }
+    PXBackupStaleWorkspaceCleanupCloseCandidates(candidates, candidateCount);
+    _removedEntryCount = state.removedEntries;
+
+    PXBackupStaleWorkspaceCleanupTraversalState finalState = {0};
+    finalState.workspaceDevice = _bundleIdentity.st_dev;
+    NSArray<NSData *> *finalNames = nil;
+    NSError *finalError = nil;
+    if (!PXBackupStaleWorkspaceCleanupScanEntryNames(
+            _bundleDescriptor,
+            &finalState,
+            &finalNames,
+            &finalError)) {
+        _cleanupFailed = YES;
+        if (error) *error = PXBackupStaleWorkspaceCleanupErrorOrMissing(finalError);
+        return NO;
+    }
+    for (NSData *nameData in finalNames) {
+        if (PXBackupStaleWorkspaceCleanupReservedPrefix(nameData)) {
+            _cleanupFailed = YES;
+            PXBackupStaleWorkspaceCleanupSetError(
+                error,
+                PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete,
+                PXBackupStaleWorkspaceCleanupEntryField,
+                @"Reserved stale-workspace evidence remains after cleanup");
+            return NO;
+        }
+    }
+    NSError *finalLockError = nil;
+    if (![_bundleLock validateOwnershipWithError:&finalLockError] ||
+        !PXBackupStaleWorkspaceCleanupPathMatchesDescriptor(
+            _canonicalBundleDirectoryPath,
+            _bundleDescriptor,
+            &_bundleIdentity,
+            NO,
+            NULL)) {
+        (void)finalLockError;
+        _cleanupFailed = YES;
+        PXBackupStaleWorkspaceCleanupSetError(
+            error,
+            PXBackupStaleWorkspaceCleanupErrorFilesystemChanged,
+            PXBackupStaleWorkspaceCleanupParentField,
+            @"The stale-cleanup authority changed after cleanup");
+        return NO;
+    }
+    _cleanupCompleted = YES;
+    if (error) *error = nil;
+    return YES;
+}
+
+- (void)dealloc {
+    if (_bundleDescriptor >= 0) {
+        close(_bundleDescriptor);
+        _bundleDescriptor = -1;
+    }
+}
+
+@end
diff --git a/AppDataBackupManager.m b/AppDataBackupManager.m
index 41a853e..6b2adc2 100644
--- a/AppDataBackupManager.m
+++ b/AppDataBackupManager.m
@@ -18,6 +18,8 @@
 #import "PXBackupManifestWriter.h"
 #import "PXBackupDirectoryPublisher.h"
 #import "PXBackupFailureCleanup.h"
+#import "PXBackupDirectoryDiscovery.h"
+#import "PXBackupStaleWorkspaceCleanup.h"
 #import "PXBackupPublicationWorkspace.h"
 #import "PXRestorePlan.h"
 #import "PXAppGroupRestoreTargetPlan.h"
@@ -1529,57 +1531,24 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
 }

 - (NSArray<NSString *> *)listBackupDirectoriesForBundleID:(NSString *)bundleID {
-    if (!bundleID.length) {
+    if (![bundleID isKindOfClass:[NSString class]] || bundleID.length == 0) {
         return @[];
     }
-    NSString *dir = [[self _backupRoot] stringByAppendingPathComponent:bundleID];
-    NSFileManager *fm = [NSFileManager defaultManager];
-
-    NSMutableArray<NSString *> *dirs = [NSMutableArray array];
-
-    BOOL isDir = NO;
-    if ([fm fileExistsAtPath:dir isDirectory:&isDir] && isDir) {
-        NSArray<NSString *> *items = [fm contentsOfDirectoryAtPath:dir error:nil];
-        for (NSString *item in items) {
-            if ([item hasPrefix:PXBackupPublicationPartialDirectoryPrefix]) {
-                continue;
-            }
-            NSString *path = [dir stringByAppendingPathComponent:item];
-            BOOL itemIsDir = NO;
-            if ([fm fileExistsAtPath:path isDirectory:&itemIsDir] && itemIsDir) {
-                NSString *manifest = [path stringByAppendingPathComponent:@"manifest.plist"];
-                if ([fm fileExistsAtPath:manifest]) {
-                    [dirs addObject:path];
-                }
-            }
-        }
-    }
-
-    // Also include legacy global backups if present (so users can migrate smoothly)
-    NSString *legacyDir = [[PXWeaponXBasePath() stringByAppendingPathComponent:@"Backups"] stringByAppendingPathComponent:bundleID];
-    BOOL legacyIsDir = NO;
-    if (![legacyDir isEqualToString:dir] && [fm fileExistsAtPath:legacyDir isDirectory:&legacyIsDir] && legacyIsDir) {
-        NSArray<NSString *> *legacyItems = [fm contentsOfDirectoryAtPath:legacyDir error:nil];
-        for (NSString *item in legacyItems) {
-            if ([item hasPrefix:PXBackupPublicationPartialDirectoryPrefix]) {
-                continue;
-            }
-            NSString *path = [legacyDir stringByAppendingPathComponent:item];
-            BOOL itemIsDir = NO;
-            if ([fm fileExistsAtPath:path isDirectory:&itemIsDir] && itemIsDir) {
-                NSString *manifest = [path stringByAppendingPathComponent:@"manifest.plist"];
-                if ([fm fileExistsAtPath:manifest]) {
-                    [dirs addObject:path];
-                }
-            }
-        }
+    NSString *currentRoot = [self _backupRoot];
+    NSString *legacyRoot = [PXWeaponXBasePath()
+        stringByAppendingPathComponent:@"Backups"];
+    NSMutableArray<NSString *> *roots = [NSMutableArray arrayWithObject:currentRoot];
+    if (![legacyRoot isEqualToString:currentRoot]) {
+        [roots addObject:legacyRoot];
     }
-
-    [dirs sortUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
-        // Sort newest-first based on the last path component (timestamp folder convention).
-        return [b.lastPathComponent compare:a.lastPathComponent];
-    }];
-    return dirs;
+    NSError *discoveryError = nil;
+    NSArray<NSString *> *directories =
+        [PXBackupDirectoryDiscovery
+            discoverBackupDirectoriesAtBackupRoots:roots
+                                   bundleIdentifier:bundleID
+                                              error:&discoveryError];
+    (void)discoveryError;
+    return directories ?: @[];
 }

 - (NSDictionary *)readManifestAtBackupDirectory:(NSString *)backupDir
@@ -1659,6 +1628,41 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
             });
             return;
         }
+        NSError *staleCleanupFactoryError = nil;
+        __attribute__((objc_precise_lifetime))
+        PXBackupStaleWorkspaceCleanup *staleWorkspaceCleanup =
+            [PXBackupStaleWorkspaceCleanup cleanupForBundleLock:bundleLock
+                                                          error:&staleCleanupFactoryError];
+        if (!staleWorkspaceCleanup) {
+            dispatch_async(dispatch_get_main_queue(), ^{
+                if (completion) completion(nil, staleCleanupFactoryError);
+            });
+            return;
+        }
+        NSError *initialStaleCleanupIdentityError = nil;
+        if (![staleWorkspaceCleanup
+                validateIdentityWithError:&initialStaleCleanupIdentityError]) {
+            dispatch_async(dispatch_get_main_queue(), ^{
+                if (completion) completion(nil, initialStaleCleanupIdentityError);
+            });
+            return;
+        }
+        NSError *staleCleanupExecutionError = nil;
+        if (![staleWorkspaceCleanup
+                removeStaleWorkspacesWithError:&staleCleanupExecutionError]) {
+            dispatch_async(dispatch_get_main_queue(), ^{
+                if (completion) completion(nil, staleCleanupExecutionError);
+            });
+            return;
+        }
+        NSError *finalStaleCleanupIdentityError = nil;
+        if (![staleWorkspaceCleanup
+                validateIdentityWithError:&finalStaleCleanupIdentityError]) {
+            dispatch_async(dispatch_get_main_queue(), ^{
+                if (completion) completion(nil, finalStaleCleanupIdentityError);
+            });
+            return;
+        }

         // Prefer jailbreak/Procursus tar first (often has xattrs/acl support); /usr/bin/tar on iOS may not.
         NSString *tarPath = [runner firstExistingPath:@[
```
## Whitespace, CRLF, and NUL audit
The final report and authorized source files are audited for Git whitespace errors, embedded NUL bytes, CRLF sequences, and final newline. The report is generated as UTF-8 LF text and ends with the exact two required status lines.
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
