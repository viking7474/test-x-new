# TASK-6.4 REPORT ? Add Malicious Archive Fixtures

## Result

READY_FOR_REVIEW on the Windows implementation host. The deterministic generator, corpus metadata, source-level Objective-C harness, workflow integration, static audit, protected hashes, and commit-scope gates pass locally. The macOS Objective-C compile and 86/86 runtime fixture execution remain pending GitHub Actions and are not reported as PASS.

## User authority and specification corrections

- Required baseline: `3258bc7de46ab70c307b5860e73b6c6bbd9ded29`.
- TASK-6.3 is accepted as complete even though `TASK-6.3-REVIEW.md` is absent.
- Correction 1 was applied before implementation: R011 and R012 use physical header index 1; `InvalidExtendedHeader=15`; `LimitExceeded=5`.
- The original S1 stop was correct: no implementation existed before Correction 1.
- Correction 2 selected authority A: the harness expands repository audit coverage from 1699 to 1703 guards; the audit script remains byte-identical and `tests/` remains included.
- TASK-6.5 was not started.

## Baseline and working-tree preservation

- HEAD at task start: `3258bc7de46ab70c307b5860e73b6c6bbd9ded29` (`phase6(task-6.3): add hardening static CI guards`).
- Pre-existing coordinator-owned modifications in `STATUS.md`, `ROADMAP.md`, `DECISIONS.md`, and `README.md` were not staged, reset, rewritten, deleted, or normalized.
- Pre-existing untracked task/review files were preserved.
- Production-source modification count: 0.
- Push: not performed.

## Exact authorized implementation scope

| Status | Path |
|---|---|
| A | `tests/backup-restore-hardening/generate_archive_fixtures.py` |
| A | `tests/backup-restore-hardening/PXArchiveFixtureHarness.m` |
| M | `.github/workflows/build-ios-arm.yml` |
| A | `docs/backup-restore-hardening/reports/TASK-6.4-REPORT.md` |

No production validator, artifact verifier, file-protection, manager, Makefile, static-audit, Restore, Backup, Clear, or Keychain source was modified.

## TASK-2.6 / TASK-2.6A fixture gap

The accepted source reviews established parser contracts but explicitly lacked generated archive-byte execution. TASK-6.4 closes only that fixture-execution gap: tar/gzip compatibility, malicious rejection, exact error mapping, immutable result behavior, privacy, and corpus no-mutation. It does not change production behavior.

## Fixture architecture

1. The standard-library Python generator constructs deterministic tar and gzip bytes directly.
2. Corpus metadata and checksums are emitted under a supplied fresh output root.
3. GitHub Actions compiles the unchanged production `PXBackupArchiveValidator.m` with the test-only Objective-C harness.
4. The harness creates a test-only real `PXVerifiedBackupArtifactSet`, invokes the production public API exactly once per fixture, and asserts exact results.
5. A recursive metadata-and-digest snapshot is compared after every fixture and after the full suite.

Generated archives are intentionally not committed. They are reproducible products, include large adversarial payloads, and are generated under `$RUNNER_TEMP/px-archive-fixtures`; source review remains focused on the deterministic builders and exact expectations.

## Generator CLI and dependencies

Supported modes are exactly `--self-test` and `--output <directory>`; simultaneous, unknown, or malformed modes fail deterministically without traceback. The generator targets Python 3.9+ and uses only the standard library. It does not import or invoke `subprocess`, `tarfile`, `gzip.GzipFile`, network modules, ctypes, third-party modules, host tar, host gzip, or shell archive construction.

## Deterministic gzip design

Each gzip stream is manually assembled with ID1/ID2 `1f 8b`, CM 8, FLG 0, MTIME 0, XFL 0, OS 255. DEFLATE uses only stored blocks with at most 65535 payload bytes and exact LEN/NLEN complements. The trailer contains unsigned CRC-32 and ISIZE modulo 2^32. No compressor-version output participates.

## Tar and extended-header design

The generator implements exact 512-byte legacy, POSIX ustar, and GNU headers; octal and nonnegative GNU base-256 size fields; unsigned and historical signed-byte checksums; payload padding; two zero end blocks; iterative PAX record lengths; raw malformed PAX payloads; GNU L/K metadata; and deliberate truncation. Requested malformed bytes are never silently repaired.

R011 and R012 each use a valid PAX `x` pseudo-header at physical index 0 followed by the real member at physical index 1. Therefore their exact field is `$.artifacts[0].members[1].path`, matching production physical-header indexing.

## Output-root safety

The output path must be nonempty and absent, its parent must be a real directory, the root is created mode 0700, files are mode 0600, writes use temporary siblings and atomic rename, metadata/checksum files are written last, symlinks are not followed, existing corpora are never overwritten, partial roots are removed on failure, and no file is written outside the supplied root.

## Corpus schema and checksum schema

- Top-level JSON keys: `schemaVersion`, `fixtureCount`, `acceptedCount`, `rejectedCount`, `cases`.
- Exact counts: 86 total, 20 accepted, 66 rejected.
- Case order: A001?A020 then R001?R066.
- JSON: sorted keys, compact separators, ASCII escaping, UTF-8 LF, one final LF.
- `corpus.sha256`: 86 archives plus `fixtures.json`, sorted by UTF-8 filename bytes; `corpus.sha256` excludes itself.

## Generator self-tests and determinism

- `python -m py_compile`: PASS.
- `archive fixture generator self-test: PASS (86/86)`.
- Two independently generated corpora: byte-identical files, metadata, checksum list, modes, total byte count, and per-case digests.
- Archive payload total: `16963002` bytes.
- Aggregate archive SHA-256 in filename order: `da09e39ace02761c018ffae2d6208f3bffc2762717ca0e2cdf24bb75b7527047`.
- `fixtures.json` SHA-256: `78c6f807c22a1563a5f62680068ffb42f9019473e0a12711259c905c710857e5`.
- `corpus.sha256` SHA-256: `0e897a9e8f3ed75a6c8188bca0bf24c9d03032b14761c2344cd0e47b9a671c9c`.
- Generated archive corpus remaining in working tree: 0 files.

## Objective-C harness architecture

The harness imports Foundation, CommonCrypto, POSIX headers, `PXBackupArchiveValidator.h`, and `PXBackupArtifactVerifier.h`. It does not compile or shadow the artifact verifier, validator, or result implementations; does not import UIKit/Security/dispatch; and does not invoke NSTask, spawn, shell, tar, network, or libarchive facilities.

The test-only verified artifact set copies its initializer dictionary, sorts artifact names by `compare:`, returns nil for unknown/nil/non-string/empty lookup, returns self from `copyWithZone:`, performs no filesystem mutation, and exposes immutable snapshots.

Harness CLI is exactly `px-archive-fixture-tests <absolute-path-to-fixtures.json>`. Metadata/schema/corpus failures exit 2; assertion failures exit 1; complete success prints `archive fixtures: PASS (86/86; accepted=20 rejected=66)` and exits 0.

For each fixture the harness builds only the required artifacts/data/appGroups/profileAppData/globalSafari manifest fields, maps the verified archive to its canonical fixture path, and calls `validatedArchivesForManifest:backupDirectory:verifiedArtifacts:error:` exactly once with no retry or alternate parser.

Accepted cases require a nonnil result, nil error, exact archive names, exact containment responses, exact member and regular-byte totals, copy identity, and immutable result collections. Rejected cases require nil result, exact domain/code/field, exactly two userInfo keys, nonempty generic description, and privacy checks against fixture roots, paths, names, malicious values, sizes, digests, PAX values, and header bytes.

The no-mutation snapshot includes relative path, object type, mode, uid, gid, nlink, device, inode, size, mtime/ctime seconds and nanoseconds, and SHA-256 for every regular file; atime is ignored. It is compared after every fixture and after the suite. Runtime no-mutation status remains pending macOS/GitHub execution.

## Accepted fixture matrix

| ID | Fixture | Archive | Members | Regular bytes | Declared bytes | Declared SHA-256 |
|---|---|---|---:|---:|---:|---|
| A001 | POSIX ustar directory plus regular file | `A001.tar.gz` | 2 | 3 | 2583 | `35cc99f022363589fafa9fb25e81074246eed283f22d422d8a609df1407f2067` |
| A002 | Legacy empty-magic regular file | `A002.tar.gz` | 1 | 1 | 2071 | `d545390191855319b84b22a9f9d066a53332d6dce0aabb0f54f717beb8b27083` |
| A003 | GNU regular file with nonempty old-prefix bytes | `A003.tar.gz` | 1 | 1 | 2071 | `95a60c890a30a29bac5022502881854e94ac74f306e4a1b1b2110363f70deed8` |
| A004 | POSIX prefix/name composition | `A004.tar.gz` | 1 | 1 | 2071 | `45eef0d1862e5cc95be99286afeda5fef25b2b04623d4eb53118f67618945a9c` |
| A005 | Dot directory root marker followed by file | `A005.tar.gz` | 2 | 1 | 2583 | `a069067158009d54c15e59e163bcd8ecf8637c79d560f668331a7a967178297c` |
| A006 | Repeated leading dot-slash components | `A006.tar.gz` | 1 | 1 | 2071 | `7c1ee4e7e7e2821532c133bd3bcc4d02f4f850c9f848e5e7aa9b5a99e1030668` |
| A007 | Directory name with one trailing slash | `A007.tar.gz` | 1 | 0 | 1559 | `ccfb9a73ee4b3c1c6cfeced298d7ebe254f8011b9c4d5c8c8fc32308b820c779` |
| A008 | Zero-length regular file | `A008.tar.gz` | 1 | 0 | 1559 | `4cf44b6378a66728528e3061592d06d9567330cdefc3f28aa911b861a665ca67` |
| A009 | Nonzero ordinary payload-padding bytes | `A009.tar.gz` | 1 | 1 | 2071 | `b24975555a7b4680b3b891a09ec69d475b0c81325ade7cfa67099619460ffdf9` |
| A010 | Per-entry PAX path override | `A010.tar.gz` | 1 | 0 | 2583 | `9dddf82165e507661c24cc2ecb5de02c7c58edd571d61f485a345c6b3ff97168` |
| A011 | Per-entry PAX size override | `A011.tar.gz` | 1 | 3 | 3095 | `4f9bfe73d35501968334dcd0ccf390b33644c7e0f14ffec50474a1635c1ec567` |
| A012 | Unknown well-formed per-entry PAX UTF-8 key/value | `A012.tar.gz` | 1 | 1 | 3095 | `0b6813febee00dd467f84aaaf392564aff84f068a8695e3e3f346a51b4175d91` |
| A013 | Unknown PAX value with invalid UTF-8 but no NUL | `A013.tar.gz` | 1 | 1 | 3095 | `4daf75e0e459354ec0e8d974550412e62b7d743d2cbb21513a028ae62e6ab5ca` |
| A014 | Unknown well-formed global PAX metadata | `A014.tar.gz` | 1 | 1 | 3095 | `e842c6aee986b535e20c87427d576183ccba631896b41a0e6446fa2add5cc171` |
| A015 | GNU L long pathname | `A015.tar.gz` | 1 | 0 | 2583 | `f71117530f39b43eecce427e7cf927c8d50f08ab11862bc2be56121732e7e8a3` |
| A016 | Exact 255-byte path component | `A016.tar.gz` | 1 | 0 | 2583 | `3325ac06c94b65533f1b1d6d8e6f3cf606f54dfe3bcd8a90f09fdc196f1a4ecc` |
| A017 | Exact 4096-byte normalized path | `A017.tar.gz` | 1 | 0 | 6679 | `24ffcd807c6bbc5862a75bbcf125d2bdb2dea2e9ccc83a9b895c2c465a4765ea` |
| A018 | Nonnegative GNU base-256 zero-size field | `A018.tar.gz` | 1 | 0 | 1559 | `4e1c869bc51d3ec247559aafab625e2228b6a3a2c3b1ec308a3d9dd79333e530` |
| A019 | Extra decompressed zero blocks after end marker | `A019.tar.gz` | 1 | 1 | 3607 | `69d409d291cf584842e7c5b01b6e7bef9fbe6bcd2d77580c2b7e3f9caa6da66f` |
| A020 | Explicit directory after implicit parent | `A020.tar.gz` | 2 | 1 | 2583 | `5c5a2f534918bd99998ac87e540eb2d69f684e65c568d29baa720729e5ff1536` |

## Rejected fixture matrix

| ID | Fixture | Error | Code | Exact field | Declared bytes | Declared SHA-256 |
|---|---|---|---:|---|---:|---|
| R001 | Absolute member path | UnsafeEntryPath | 8 | `$.artifacts[0].members[0].path` | 1559 | `491622e9bb01b2ae7d9412a0f64c4a2efa37f7221d83323749fb23e28168867e` |
| R002 | Dot-dot traversal component | UnsafeEntryPath | 8 | `$.artifacts[0].members[0].path` | 1559 | `bdcc70544d67f474a441af67811de3fcfee61ad58620fdf9c29b22e9f11ebdf8` |
| R003 | Remaining dot component | UnsafeEntryPath | 8 | `$.artifacts[0].members[0].path` | 1559 | `821b1cd6a3efdf5e31a5867d62dcfbd31b8c554bc2f3cf8901744e5956462046` |
| R004 | Backslash in member path | UnsafeEntryPath | 8 | `$.artifacts[0].members[0].path` | 1559 | `c680bc9f62880a352b0e914a326fa5c1e31d0379406e212a6d00384f8bd793d0` |
| R005 | Doubled slash | UnsafeEntryPath | 8 | `$.artifacts[0].members[0].path` | 1559 | `d12cff96bdb849382af783fe86aa07ec1aab54647f4f567d8c3c951363571091` |
| R006 | Control character in path | UnsafeEntryPath | 8 | `$.artifacts[0].members[0].path` | 1559 | `5245cbee9d97de29a32189aa03c4a720ef8c18b96928ed1453d7003daf0a7b18` |
| R007 | Invalid UTF-8 path with unsigned checksum | UnsafeEntryPath | 8 | `$.artifacts[0].members[0].path` | 1559 | `bbda02f03901a7bf3e8b9dbbe125ee1a4ac041e808db31e0d4ba5530bcd06994` |
| R008 | Invalid UTF-8 path with historical signed checksum | UnsafeEntryPath | 8 | `$.artifacts[0].members[0].path` | 1559 | `3fe4f1d88382eb2539d3388a29b1c5d438ca63a975fc2afafc343f2111482507` |
| R009 | Regular-file path ending in slash | UnsafeEntryPath | 8 | `$.artifacts[0].members[0].path` | 1559 | `b691b2497cfee3921660195a7a8b0bc4c5f3295c494bdd924ba3f5ac170456cc` |
| R010 | Root marker used as regular file | UnsafeEntryPath | 8 | `$.artifacts[0].members[0].path` | 1559 | `635bd6ae5e1b6221b06add4e2ffa16f9fb60f44fa8b82abe9866ec0ee3facf09` |
| R011 | 256-byte effective-path component supplied by PAX | LimitExceeded | 12 | `$.artifacts[0].members[1].path` | 2583 | `a84615df5052e840e11ca73d458c92dba45a1eff11b8fbc0922eccdbd376beac` |
| R012 | 4097-byte normalized effective path supplied by PAX | LimitExceeded | 12 | `$.artifacts[0].members[1].path` | 6679 | `9b16051ad0f532b86c572f761cca7ecc3869b70c88706dbb502a2a505574a5a1` |
| R013 | Duplicate exact member path | DuplicateEntry | 9 | `$.artifacts[0].members[1].path` | 2071 | `19c2cfa9ee7d0c01caf51dd8503471e6715d3eaffb9b7f08dcffb7a1d01936b3` |
| R014 | Duplicate after leading dot-slash normalization | DuplicateEntry | 9 | `$.artifacts[0].members[1].path` | 2071 | `a84a1f798a72731161ba822be9b4f171000c462e8dd8cf5bd8c676da7dc383a4` |
| R015 | Regular file followed by child beneath it | DuplicateEntry | 9 | `$.artifacts[0].members[1].path` | 2071 | `a20013fe3e803f0de49c3bca85eaecd4137b6cf1e51e2746902935127244827f` |
| R016 | Child first then regular file at implicit parent | DuplicateEntry | 9 | `$.artifacts[0].members[1].path` | 2071 | `e1d9881edc663729bcd35a47e548cc46ad7671998c051742df827d4cf2c5bb40` |
| R017 | Same normalized path used as file and directory | DuplicateEntry | 9 | `$.artifacts[0].members[1].path` | 2071 | `30195be1290ac05e0319db8bd1e2e7aaf30b588731d1c0ac81eda5c2256eac51` |
| R018 | Symbolic link | UnsupportedEntryType | 10 | `$.artifacts[0].members[0].type` | 1559 | `9af8c80b8b0171557ca5a021ce3a0ca1649830bd5836c07d9e942e4865da9dc1` |
| R019 | Hard link | UnsupportedEntryType | 10 | `$.artifacts[0].members[0].type` | 1559 | `6bd9c7a589529c98b2c27ab1ccc383e7f1cf2ebf5412b5655d8e931cc3e25928` |
| R020 | Character device | UnsupportedEntryType | 10 | `$.artifacts[0].members[0].type` | 1559 | `f4aff97854a5f85a059f672a04fc4ea349628bd45c4cb60059838aef37870893` |
| R021 | Block device | UnsupportedEntryType | 10 | `$.artifacts[0].members[0].type` | 1559 | `57eb5d4abae09fb7ae52dffeb709ccf83bfd177443530c3ca162ec0f34e19957` |
| R022 | FIFO | UnsupportedEntryType | 10 | `$.artifacts[0].members[0].type` | 1559 | `0db5cf09cd85be9c77a15d73cc0f61cedf4dcc7cc87408fde014325720cce1b5` |
| R023 | Contiguous-file type 7 | UnsupportedEntryType | 10 | `$.artifacts[0].members[0].type` | 1559 | `1774041714fd2ae2d899bec10c28ea3af85efc85db8f9c44abb4d6ca43bce7f3` |
| R024 | GNU sparse type S | UnsupportedEntryType | 10 | `$.artifacts[0].members[0].type` | 1559 | `d7884cf1b8453a937e2c22b3135ccb100e6f3b58ddf120ec5acf30e609c38f52` |
| R025 | Unknown vendor type | UnsupportedEntryType | 10 | `$.artifacts[0].members[0].type` | 1559 | `91561b5ebcf3c7a856a450788a1e8b79e41bf5ae184bb83ed422d70829ac49a1` |
| R026 | Setuid member mode | UnsupportedEntryType | 10 | `$.artifacts[0].members[0].type` | 1559 | `8e07972ef6d6760080b73e579071c4b5dfb64695f3a0f7368df7a4ff8b84d72e` |
| R027 | Setgid member mode | UnsupportedEntryType | 10 | `$.artifacts[0].members[0].type` | 1559 | `1f83b61c4e4e1c6e165210475ca3a6027054e9690bec51699885035dcf2dba60` |
| R028 | Directory with nonzero effective size | InvalidHeader | 7 | `$.artifacts[0].members[0].type` | 2071 | `3e3c54386289bbb991611541d1876e704256fe1f95413d09ffcfe23f540d6ebd` |
| R029 | Invalid tar checksum | InvalidHeader | 7 | `$.artifacts[0].members[0]` | 1559 | `9d297733ad5ba2715bf61f3c24cf40d281998ac0114517fb035455d1b129e676` |
| R030 | Unsupported nonempty magic | InvalidHeader | 7 | `$.artifacts[0].members[0]` | 1559 | `ba957b1675a7268b995fba59ad4325e70a45e1f826d03e9242eba5da719c73ab` |
| R031 | POSIX magic with wrong version | InvalidHeader | 7 | `$.artifacts[0].members[0]` | 1559 | `07213cff0077959ac18b64032fa367168778b38b7bd0d7a84c3645cdadaad0ba` |
| R032 | GNU magic with wrong version | InvalidHeader | 7 | `$.artifacts[0].members[0]` | 1559 | `6e447539cf5ef276069dd91b01fa0e2af0bbba8c005b8ef6b459063288b273db` |
| R033 | Invalid octal numeric field | InvalidHeader | 7 | `$.artifacts[0].members[0]` | 1559 | `0624f7d9067c2c9f1645d125c156da04b3d7c5545d1d099d61ffbd95b0259024` |
| R034 | Negative GNU base-256 size | InvalidHeader | 7 | `$.artifacts[0].members[0]` | 1559 | `f8b08334be830e9ded91ab4c349f25638526846d605560f78e4ea91aeda4d29a` |
| R035 | Logical regular-file size greater than 64 GiB | LimitExceeded | 12 | `$.artifacts[0].members[0].type` | 1559 | `8b62dd683892e5205e1c18110a3523971d78290648cf7ec50a791fe7b2583104` |
| R036 | Single zero block followed by nonzero header | InvalidHeader | 7 | `$.artifacts[0].members[1]` | 2583 | `d5368885b537a89c0bd5493b0ce472439c1a7eb270d5e9774766131e63d5aa4b` |
| R037 | Complete member with no tar end marker | TruncatedArchive | 6 | `$.artifacts[0].members[1]` | 535 | `fc05f6195d17f155721bc1b89264095e31ca2401a532fafe2c9d20b5e4764fa6` |
| R038 | Only one zero termination block | TruncatedArchive | 6 | `$.artifacts[0].members[1]` | 1047 | `c5cf249431aa34133a59cefd5e3b46517ec2ff802b05baaf3da5d798d990025b` |
| R039 | Stream ending inside next tar header | TruncatedArchive | 6 | `$.artifacts[0].members[1]` | 636 | `1f1592df7f79977da41522c6b49fae72126c8983033a8cce5d4a8644c073ed2f` |
| R040 | Stream ending inside member payload | TruncatedArchive | 6 | `$.artifacts[0].members[1]` | 540 | `c4822cf975ca94191194799a8b1921acccd9d72d2ae4b9421f653c90733223b6` |
| R041 | Stream ending inside member padding | TruncatedArchive | 6 | `$.artifacts[0].members[1]` | 636 | `b714ecf3d0ecd5cc710927d2bf5dd2332a2077cff91d5473d6afc85a384e6293` |
| R042 | Nonzero decompressed byte after end marker | InvalidHeader | 7 | `$.artifacts[0].members[1]` | 1560 | `427337829c74265f9c1dab2873d4a862427e3ef72bb83b0757a9e85d035b960d` |
| R043 | Invalid gzip compression method or header | UnsupportedCompression | 5 | `$.data.archive` | 2071 | `a5a3bbbde853d3a58227dd7e423e9a0464c7f1ee958dd88f2227b26de41d56b4` |
| R044 | Gzip EOF before Z_STREAM_END | TruncatedArchive | 6 | `$.data.archive` | 2070 | `94c3417375e04293be4ad7cd0aedb838eb9aae483cba1433762864ce3934a3c8` |
| R045 | Concatenated second gzip member | UnsupportedCompression | 5 | `$.data.archive` | 3630 | `3aaf662e7f313733760c519d3092300b3381db08cbe2a78d062276a6cc87dddc` |
| R046 | Trailing compressed garbage | UnsupportedCompression | 5 | `$.data.archive` | 2097 | `844ec1c530b27fec589bf366978237259fcd6816bf8dff64338e7737288da672` |
| R047 | Malformed PAX decimal length | InvalidExtendedHeader | 11 | `$.artifacts[0].members[0]` | 2071 | `54df0ab8a09cc5f5dd48521b72c342a745af3f532802610fc30a90ef92903a01` |
| R048 | PAX record missing newline | InvalidExtendedHeader | 11 | `$.artifacts[0].members[0]` | 2071 | `536e653a34f6828af7f84ac196352c023f5ccbe6116c71b69cd6da0658a15f2f` |
| R049 | PAX record missing equals | InvalidExtendedHeader | 11 | `$.artifacts[0].members[0]` | 2071 | `f2a6e12efcc44d33e5e4a24d07bd21dba79a1aa00aa8464ab3828d93bd8c1a6c` |
| R050 | PAX record containing NUL | InvalidExtendedHeader | 11 | `$.artifacts[0].members[0]` | 2071 | `d6a6e9c2e1932ea62b02f3c8208575e31b401386ec1faf75fd31997bb43b82c9` |
| R051 | Invalid PAX key bytes | InvalidExtendedHeader | 11 | `$.artifacts[0].members[0]` | 2071 | `7f53b439c9665f556f509ed9a6aed5089c6c23fba1d69431413f9863b1742315` |
| R052 | Duplicate path override in one PAX payload | InvalidExtendedHeader | 11 | `$.artifacts[0].members[0]` | 2071 | `9a80a6c7a0f47e2093feb8a70dfb66ecf8ce698d70338b0d25b9ce5e1aee3d0a` |
| R053 | Global PAX path override | InvalidExtendedHeader | 11 | `$.artifacts[0].members[0]` | 2071 | `c6a32905663dc090553cd79cae4fe20ccb5f2d9d3b9ce968f0a82f3cb7e1872a` |
| R054 | GNU.sparse PAX key | UnsupportedEntryType | 10 | `$.artifacts[0].members[0]` | 2071 | `3f87b8813b9a531ae740b1c44f81eb43bc90e6b7cc32073c23bff340e7e1687a` |
| R055 | Invalid UTF-8 reserved PAX path | InvalidExtendedHeader | 11 | `$.artifacts[0].members[0]` | 2071 | `da064ee45d705f6c90cc545a6f33c36c65e3e837d798fb3e22ea18d9ce545032` |
| R056 | Invalid decimal PAX size | InvalidExtendedHeader | 11 | `$.artifacts[0].members[0]` | 2071 | `0e0f04ac70ae9d19deb7c9dc7022df03309e15df63893b0a07a2f736c0a2efa8` |
| R057 | Pending PAX path followed by GNU L path | InvalidExtendedHeader | 11 | `$.artifacts[0].members[1]` | 3095 | `24286821b61c6e0e64b910f366c08c9e2c3fc92e5ab219cd845a727d30272671` |
| R058 | Empty GNU long-name payload | InvalidExtendedHeader | 11 | `$.artifacts[0].members[0]` | 2071 | `8d59520f26ecd27ef69cd9ff9700018221f59ffa37b4adeed753172768dd9f0a` |
| R059 | GNU long-name payload with interior NUL | InvalidExtendedHeader | 11 | `$.artifacts[0].members[0]` | 2071 | `0a92e070e87fcbf6152465b0d185acee2b537532693c530180e8c20542adfad6` |
| R060 | GNU long-name payload with invalid UTF-8 | InvalidExtendedHeader | 11 | `$.artifacts[0].members[0]` | 2071 | `bbb5a65f04c183d779d38f846987c2392040e977a4e69264ee642196abe3c887` |
| R061 | GNU K link metadata attached to regular member | InvalidExtendedHeader | 11 | `$.artifacts[0].members[1].type` | 2583 | `7ace0cedfbf726e16d09561820c70251362774467a42a1f5537904e5293402ec` |
| R062 | Per-entry metadata left pending at tar end | InvalidExtendedHeader | 11 | `$.artifacts[0].members[1]` | 2071 | `5716ce2469135c57439873477ed3f5b659d8608c572a2e9de8c38033714605aa` |
| R063 | One metadata header declaring 1 MiB plus one byte | LimitExceeded | 12 | `$.artifacts[0].members[0]` | 1559 | `cf3a3093041110042f03f0bb831c31f592a8a82288c49611ea1633cf24086dad` |
| R064 | Seventeenth 1 MiB metadata header exceeds 16 MiB total | LimitExceeded | 12 | `$.artifacts[0].members[16]` | 16788247 | `a48fac68232fb2ba5927258c798997254dfeb5a469a4b5d18e603ed8fc1e35c4` |
| R065 | Manifest compressed-size declaration differs by one byte | SizeMismatch | 13 | `$.data.archive` | 2072 | `f3c1ce6b2f4b7dac4b2fcf6b801f974edb5bf7389d94bdb357520cc1bf6eca48` |
| R066 | Manifest compressed SHA-256 differs by one nibble | DigestMismatch | 14 | `$.data.archive` | 2071 | `03c1ce6b2f4b7dac4b2fcf6b801f974edb5bf7389d94bdb357520cc1bf6eca48` |

## Error-code distribution

| Error | Count |
|---|---:|
| UnsupportedCompression | 3 |
| TruncatedArchive | 6 |
| InvalidHeader | 9 |
| UnsafeEntryPath | 10 |
| DuplicateEntry | 5 |
| UnsupportedEntryType | 11 |
| InvalidExtendedHeader | 15 |
| LimitExceeded | 5 |
| SizeMismatch | 1 |
| DigestMismatch | 1 |
| **Total** | **66** |

The corrected distribution is `InvalidExtendedHeader=15` and `LimitExceeded=5`; R054 remains `UnsupportedEntryType`.

## Error-field distribution

| Exact field | Count |
|---|---:|
| `$.artifacts[0].members[0]` | 20 |
| `$.artifacts[0].members[0].path` | 10 |
| `$.artifacts[0].members[0].type` | 12 |
| `$.artifacts[0].members[16]` | 1 |
| `$.artifacts[0].members[1]` | 9 |
| `$.artifacts[0].members[1].path` | 7 |
| `$.artifacts[0].members[1].type` | 1 |
| `$.data.archive` | 6 |

## Per-case encoded result table

| ID | Disposition | Expected result | Expected error | Mutation expectation |
|---|---|---|---|---|
| A001 | accepted | members=2; regularBytes=3 | `nil` | Exact baseline snapshot retained |
| A002 | accepted | members=1; regularBytes=1 | `nil` | Exact baseline snapshot retained |
| A003 | accepted | members=1; regularBytes=1 | `nil` | Exact baseline snapshot retained |
| A004 | accepted | members=1; regularBytes=1 | `nil` | Exact baseline snapshot retained |
| A005 | accepted | members=2; regularBytes=1 | `nil` | Exact baseline snapshot retained |
| A006 | accepted | members=1; regularBytes=1 | `nil` | Exact baseline snapshot retained |
| A007 | accepted | members=1; regularBytes=0 | `nil` | Exact baseline snapshot retained |
| A008 | accepted | members=1; regularBytes=0 | `nil` | Exact baseline snapshot retained |
| A009 | accepted | members=1; regularBytes=1 | `nil` | Exact baseline snapshot retained |
| A010 | accepted | members=1; regularBytes=0 | `nil` | Exact baseline snapshot retained |
| A011 | accepted | members=1; regularBytes=3 | `nil` | Exact baseline snapshot retained |
| A012 | accepted | members=1; regularBytes=1 | `nil` | Exact baseline snapshot retained |
| A013 | accepted | members=1; regularBytes=1 | `nil` | Exact baseline snapshot retained |
| A014 | accepted | members=1; regularBytes=1 | `nil` | Exact baseline snapshot retained |
| A015 | accepted | members=1; regularBytes=0 | `nil` | Exact baseline snapshot retained |
| A016 | accepted | members=1; regularBytes=0 | `nil` | Exact baseline snapshot retained |
| A017 | accepted | members=1; regularBytes=0 | `nil` | Exact baseline snapshot retained |
| A018 | accepted | members=1; regularBytes=0 | `nil` | Exact baseline snapshot retained |
| A019 | accepted | members=1; regularBytes=1 | `nil` | Exact baseline snapshot retained |
| A020 | accepted | members=2; regularBytes=1 | `nil` | Exact baseline snapshot retained |
| R001 | rejected | nil | `UnsafeEntryPath(8) at $.artifacts[0].members[0].path` | Exact baseline snapshot retained |
| R002 | rejected | nil | `UnsafeEntryPath(8) at $.artifacts[0].members[0].path` | Exact baseline snapshot retained |
| R003 | rejected | nil | `UnsafeEntryPath(8) at $.artifacts[0].members[0].path` | Exact baseline snapshot retained |
| R004 | rejected | nil | `UnsafeEntryPath(8) at $.artifacts[0].members[0].path` | Exact baseline snapshot retained |
| R005 | rejected | nil | `UnsafeEntryPath(8) at $.artifacts[0].members[0].path` | Exact baseline snapshot retained |
| R006 | rejected | nil | `UnsafeEntryPath(8) at $.artifacts[0].members[0].path` | Exact baseline snapshot retained |
| R007 | rejected | nil | `UnsafeEntryPath(8) at $.artifacts[0].members[0].path` | Exact baseline snapshot retained |
| R008 | rejected | nil | `UnsafeEntryPath(8) at $.artifacts[0].members[0].path` | Exact baseline snapshot retained |
| R009 | rejected | nil | `UnsafeEntryPath(8) at $.artifacts[0].members[0].path` | Exact baseline snapshot retained |
| R010 | rejected | nil | `UnsafeEntryPath(8) at $.artifacts[0].members[0].path` | Exact baseline snapshot retained |
| R011 | rejected | nil | `LimitExceeded(12) at $.artifacts[0].members[1].path` | Exact baseline snapshot retained |
| R012 | rejected | nil | `LimitExceeded(12) at $.artifacts[0].members[1].path` | Exact baseline snapshot retained |
| R013 | rejected | nil | `DuplicateEntry(9) at $.artifacts[0].members[1].path` | Exact baseline snapshot retained |
| R014 | rejected | nil | `DuplicateEntry(9) at $.artifacts[0].members[1].path` | Exact baseline snapshot retained |
| R015 | rejected | nil | `DuplicateEntry(9) at $.artifacts[0].members[1].path` | Exact baseline snapshot retained |
| R016 | rejected | nil | `DuplicateEntry(9) at $.artifacts[0].members[1].path` | Exact baseline snapshot retained |
| R017 | rejected | nil | `DuplicateEntry(9) at $.artifacts[0].members[1].path` | Exact baseline snapshot retained |
| R018 | rejected | nil | `UnsupportedEntryType(10) at $.artifacts[0].members[0].type` | Exact baseline snapshot retained |
| R019 | rejected | nil | `UnsupportedEntryType(10) at $.artifacts[0].members[0].type` | Exact baseline snapshot retained |
| R020 | rejected | nil | `UnsupportedEntryType(10) at $.artifacts[0].members[0].type` | Exact baseline snapshot retained |
| R021 | rejected | nil | `UnsupportedEntryType(10) at $.artifacts[0].members[0].type` | Exact baseline snapshot retained |
| R022 | rejected | nil | `UnsupportedEntryType(10) at $.artifacts[0].members[0].type` | Exact baseline snapshot retained |
| R023 | rejected | nil | `UnsupportedEntryType(10) at $.artifacts[0].members[0].type` | Exact baseline snapshot retained |
| R024 | rejected | nil | `UnsupportedEntryType(10) at $.artifacts[0].members[0].type` | Exact baseline snapshot retained |
| R025 | rejected | nil | `UnsupportedEntryType(10) at $.artifacts[0].members[0].type` | Exact baseline snapshot retained |
| R026 | rejected | nil | `UnsupportedEntryType(10) at $.artifacts[0].members[0].type` | Exact baseline snapshot retained |
| R027 | rejected | nil | `UnsupportedEntryType(10) at $.artifacts[0].members[0].type` | Exact baseline snapshot retained |
| R028 | rejected | nil | `InvalidHeader(7) at $.artifacts[0].members[0].type` | Exact baseline snapshot retained |
| R029 | rejected | nil | `InvalidHeader(7) at $.artifacts[0].members[0]` | Exact baseline snapshot retained |
| R030 | rejected | nil | `InvalidHeader(7) at $.artifacts[0].members[0]` | Exact baseline snapshot retained |
| R031 | rejected | nil | `InvalidHeader(7) at $.artifacts[0].members[0]` | Exact baseline snapshot retained |
| R032 | rejected | nil | `InvalidHeader(7) at $.artifacts[0].members[0]` | Exact baseline snapshot retained |
| R033 | rejected | nil | `InvalidHeader(7) at $.artifacts[0].members[0]` | Exact baseline snapshot retained |
| R034 | rejected | nil | `InvalidHeader(7) at $.artifacts[0].members[0]` | Exact baseline snapshot retained |
| R035 | rejected | nil | `LimitExceeded(12) at $.artifacts[0].members[0].type` | Exact baseline snapshot retained |
| R036 | rejected | nil | `InvalidHeader(7) at $.artifacts[0].members[1]` | Exact baseline snapshot retained |
| R037 | rejected | nil | `TruncatedArchive(6) at $.artifacts[0].members[1]` | Exact baseline snapshot retained |
| R038 | rejected | nil | `TruncatedArchive(6) at $.artifacts[0].members[1]` | Exact baseline snapshot retained |
| R039 | rejected | nil | `TruncatedArchive(6) at $.artifacts[0].members[1]` | Exact baseline snapshot retained |
| R040 | rejected | nil | `TruncatedArchive(6) at $.artifacts[0].members[1]` | Exact baseline snapshot retained |
| R041 | rejected | nil | `TruncatedArchive(6) at $.artifacts[0].members[1]` | Exact baseline snapshot retained |
| R042 | rejected | nil | `InvalidHeader(7) at $.artifacts[0].members[1]` | Exact baseline snapshot retained |
| R043 | rejected | nil | `UnsupportedCompression(5) at $.data.archive` | Exact baseline snapshot retained |
| R044 | rejected | nil | `TruncatedArchive(6) at $.data.archive` | Exact baseline snapshot retained |
| R045 | rejected | nil | `UnsupportedCompression(5) at $.data.archive` | Exact baseline snapshot retained |
| R046 | rejected | nil | `UnsupportedCompression(5) at $.data.archive` | Exact baseline snapshot retained |
| R047 | rejected | nil | `InvalidExtendedHeader(11) at $.artifacts[0].members[0]` | Exact baseline snapshot retained |
| R048 | rejected | nil | `InvalidExtendedHeader(11) at $.artifacts[0].members[0]` | Exact baseline snapshot retained |
| R049 | rejected | nil | `InvalidExtendedHeader(11) at $.artifacts[0].members[0]` | Exact baseline snapshot retained |
| R050 | rejected | nil | `InvalidExtendedHeader(11) at $.artifacts[0].members[0]` | Exact baseline snapshot retained |
| R051 | rejected | nil | `InvalidExtendedHeader(11) at $.artifacts[0].members[0]` | Exact baseline snapshot retained |
| R052 | rejected | nil | `InvalidExtendedHeader(11) at $.artifacts[0].members[0]` | Exact baseline snapshot retained |
| R053 | rejected | nil | `InvalidExtendedHeader(11) at $.artifacts[0].members[0]` | Exact baseline snapshot retained |
| R054 | rejected | nil | `UnsupportedEntryType(10) at $.artifacts[0].members[0]` | Exact baseline snapshot retained |
| R055 | rejected | nil | `InvalidExtendedHeader(11) at $.artifacts[0].members[0]` | Exact baseline snapshot retained |
| R056 | rejected | nil | `InvalidExtendedHeader(11) at $.artifacts[0].members[0]` | Exact baseline snapshot retained |
| R057 | rejected | nil | `InvalidExtendedHeader(11) at $.artifacts[0].members[1]` | Exact baseline snapshot retained |
| R058 | rejected | nil | `InvalidExtendedHeader(11) at $.artifacts[0].members[0]` | Exact baseline snapshot retained |
| R059 | rejected | nil | `InvalidExtendedHeader(11) at $.artifacts[0].members[0]` | Exact baseline snapshot retained |
| R060 | rejected | nil | `InvalidExtendedHeader(11) at $.artifacts[0].members[0]` | Exact baseline snapshot retained |
| R061 | rejected | nil | `InvalidExtendedHeader(11) at $.artifacts[0].members[1].type` | Exact baseline snapshot retained |
| R062 | rejected | nil | `InvalidExtendedHeader(11) at $.artifacts[0].members[1]` | Exact baseline snapshot retained |
| R063 | rejected | nil | `LimitExceeded(12) at $.artifacts[0].members[0]` | Exact baseline snapshot retained |
| R064 | rejected | nil | `LimitExceeded(12) at $.artifacts[0].members[16]` | Exact baseline snapshot retained |
| R065 | rejected | nil | `SizeMismatch(13) at $.data.archive` | Exact baseline snapshot retained |
| R066 | rejected | nil | `DigestMismatch(14) at $.data.archive` | Exact baseline snapshot retained |

## Local command output

```text
archive fixture generator self-test: PASS (86/86)
backup_restore_hardening self-test: PASS (49/49)
backup_restore_hardening audit: PASS (1703/1703)
```

The TASK-6.3 self-test and repository audit were each executed twice. Both runs had byte-identical stdout, byte-identical empty stderr, identical exit code 0, and identical counts.

## Harness macOS output and Apple build state

- `xcrun clang`: NOT RUN on Windows; PENDING GitHub Actions.
- Harness runtime: NOT RUN on Windows; expected success remains 86/86 PENDING GitHub Actions.
- Runtime no-mutation proof: PENDING GitHub Actions.
- Application Apple/Theos build/package: NOT RUN locally on Windows; PENDING GitHub Actions.

No GNUstep, mocked validator, alternate parser, or substituted validator implementation was used.

## Workflow integration

The following exact fail-closed block is immediately after the canonical TASK-6.3 audit and before dependency installation:

```yaml
      - name: Build and run malicious archive fixtures
        run: |
          set -euo pipefail
          FIXTURE_ROOT="$RUNNER_TEMP/px-archive-fixtures"
          FIXTURE_BIN="$RUNNER_TEMP/px-archive-fixture-tests"
          python3 tests/backup-restore-hardening/generate_archive_fixtures.py --self-test
          python3 tests/backup-restore-hardening/generate_archive_fixtures.py --output "$FIXTURE_ROOT"
          xcrun clang -fobjc-arc -fblocks -fmodules -Wno-deprecated-declarations -I. \
            PXBackupArchiveValidator.m \
            tests/backup-restore-hardening/PXArchiveFixtureHarness.m \
            -framework Foundation -lz -o "$FIXTURE_BIN"
          "$FIXTURE_BIN" "$FIXTURE_ROOT/fixtures.json"
```

- Workflow bytes: 5492.
- Workflow SHA-256: `26bd4cf807b5a2ba845a872c7f3dc4fd7ef7599f74b0e34bfeafbc90caca1060`.
- CRLF: 132; LF-only: 0; NUL: 0; final CRLF present.
- No continue-on-error, retry, allow-failure, bypass, conditional skip, or fixture subset exists.

## TASK-6.3 static-audit non-regression

- Original TASK-6.3 baseline: 1699/1699.
- TASK-6.4 with the required harness: 1703/1703.
- Delta: +4 valid environment guards.
- Python generator delta: 0 guards; report delta: 0; workflow file-count delta: 0.
- `tests/` remains included; no exclusion or special case was added.
- Audit script modified: NO.
- Audit script SHA-256: `19e1ea53fad0668256d45bb31e0323cda4133af92c39b0c7bad584dc9ac0c745`.

Exact new guards:

- `BRH-ENV-FILE-TESTS-BACKUP-RESTORE-HARDENING-PXARCHIVEFIXTUREHARNESS-M-BYTES`
- `BRH-ENV-FILE-TESTS-BACKUP-RESTORE-HARDENING-PXARCHIVEFIXTUREHARNESS-M-UTF8`
- `BRH-ENV-FILE-TESTS-BACKUP-RESTORE-HARDENING-PXARCHIVEFIXTUREHARNESS-M-NUL`
- `BRH-ENV-FILE-TESTS-BACKUP-RESTORE-HARDENING-PXARCHIVEFIXTUREHARNESS-M-CONFLICT`

## Protected hashes

| Protected path | Bytes | SHA-256 |
|---|---:|---|
| `PXBackupArchiveValidator.h` | 2361 | `661258274d798bfd67356d472334cfffcc1da6a911278ae6e956a66e0cf4b05b` |
| `PXBackupArchiveValidator.m` | 89098 | `01c8c628453b8f67853a84ebf9c5511c6a9af454c80bc476da1d9f685eaa306e` |
| `PXBackupArtifactVerifier.h` | 2006 | `2cd726496b1830cc404c6e6665e73785552a39c74cdb9683a43d32221fc194cc` |
| `PXBackupArtifactVerifier.m` | 46654 | `2c45882144f529380bf485724bdd2258a3d9dd43de232076e857f10f3d5958f9` |
| `PXFileProtection.h` | 1095 | `5c7163ec17f24c9ea4e0d4a53012fcb4c62e57decfb7891fdf8be72c554c8fb7` |
| `PXFileProtection.m` | 11505 | `a6fb37302b7b32958026ba2842563769ee0098cf1007a6500763d3ce4f231947` |
| `AppDataBackupManager.h` | 1442 | `b19c1c61e6df642468d713dede5a0c0bd0dbb6a0ac72d98ad6878d3cae1f2e75` |
| `AppDataBackupManager.m` | 239969 | `61fc1ff901d64a0b2732c1ea44f47f23209a0b55404fbc69e27889ee03939028` |
| `Makefile` | 9266 | `b2d9ca1083f85b818f132612e792c73e94e78390ef06092db2075439af945dfa` |
| `scripts/audit_backup_restore_hardening.py` | 94957 | `19e1ea53fad0668256d45bb31e0323cda4133af92c39b0c7bad584dc9ac0c745` |
| `docs/backup-restore-hardening/reports/TASK-6.3-REPORT.md` | 130823 | `da006d588bac124a62ca57c445d724a73becd2646f0ced4e1476507d9222af97` |
| `docs/backup-restore-hardening/reports/TASK-2.6A-REPORT.md` | 46401 | `16f3ee387de57519a2f4494a57f0f64ee2e0852c9ebc22376c41f8cc7d9544d2` |
| `docs/backup-restore-hardening/reviews/TASK-2.6A-REVIEW.md` | 6012 | `3e1c7d24aa7d579739053f3288f24843fd5a76511d0053813f9ae03e7cb9bcf1` |

All listed hashes match the protected baseline. Production source drift is 0.

## Encoding, NUL, and static diff gates

- Generator: UTF-8 LF, no BOM, no NUL, no lone CR, final LF.
- Harness: UTF-8 LF, no BOM, no NUL, no lone CR, final LF.
- Workflow: UTF-8 CRLF only, no BOM, no NUL, no LF-only line, final CRLF.
- Report: UTF-8 LF, no BOM, no NUL, no lone CR, final LF.
- `git diff --check`: PASS (final pre-commit four-file diff).
- Generated `.tar.gz`, `.tar`, `.gz`, `.bin`, `.json`, and checksum corpus committed: NO.

## Residual fixture limitations

TASK-6.4 does not test filesystem identity races during validation, injected mid-stream read failures, descriptor fcntl failures, transaction commit failures, rollback failures, process crashes, or device filesystem semantics. Those belong to TASK-6.5 or target-device testing.

## Explicit numbered scenarios

0001. Baseline HEAD equals the required TASK-6.3 implementation commit.
0002. Authorized scope contains exactly two new test sources, one workflow edit, and one report.
0003. Coordinator-owned STATUS remains unstaged and unmodified by this task.
0004. Coordinator-owned ROADMAP remains unstaged and unmodified by this task.
0005. Coordinator-owned DECISIONS remains unstaged and unmodified by this task.
0006. Coordinator-owned README remains unstaged and unmodified by this task.
0007. Pre-existing untracked task files remain preserved.
0008. Pre-existing untracked review files remain preserved.
0009. TASK-6.3 review-file absence is not a blocker under user authority.
0010. TASK-6.5 is not started.
0011. No production validator file is modified.
0012. No artifact verifier file is modified.
0013. No file-protection source is modified.
0014. No manager source is modified.
0015. No Makefile change is present.
0016. No audit-script change is present.
0017. Generator accepts self-test mode alone.
0018. Generator accepts output mode alone.
0019. Generator rejects simultaneous modes with exit 2.
0020. Generator rejects unknown options with exit 2.
0021. Generator rejects malformed output arguments without traceback.
0022. Generator creates no path outside the supplied root.
0023. Generator rejects an existing output root.
0024. Generator rejects a missing parent directory.
0025. Generator rejects a symlink parent or output path condition.
0026. Generator cleans partial output after injected failure.
0027. Generator writes archive files mode 0600 where supported.
0028. Generator creates output root mode 0700 where supported.
0029. Generator writes fixtures.json after archive files.
0030. Generator writes corpus.sha256 last.
0031. Gzip ID1 is 0x1f.
0032. Gzip ID2 is 0x8b.
0033. Gzip compression method is 8.
0034. Gzip flags are zero.
0035. Gzip MTIME is zero.
0036. Gzip XFL is zero.
0037. Gzip OS byte is 255.
0038. DEFLATE uses deterministic stored blocks only.
0039. Stored blocks cap payload at 65535 bytes.
0040. LEN and NLEN are exact little-endian complements.
0041. Final stored block sets BFINAL.
0042. Gzip CRC32 matches uncompressed tar bytes.
0043. Gzip ISIZE matches tar length modulo 2^32.
0044. Legacy tar magic is accepted only when all six magic bytes are zero.
0045. POSIX tar magic and version are exact.
0046. GNU tar magic and version are exact.
0047. Octal fields parse only valid octal digits and valid terminators.
0048. GNU base-256 size construction is nonnegative.
0049. Unsigned checksum construction is deterministic.
0050. Historical signed-byte checksum construction is deterministic.
0051. Payload padding reaches a 512-byte boundary.
0052. Two zero blocks form the tar end marker.
0053. PAX record length iteration stabilizes before serialization.
0054. GNU L metadata carries a long path.
0055. GNU K metadata carries a long link path.
0056. JSON top-level keys match the exact schema.
0057. JSON case keys differ exactly by accepted or rejected disposition.
0058. JSON contains 86 ordered cases.
0059. JSON contains 20 accepted cases.
0060. JSON contains 66 rejected cases.
0061. Checksum list contains 87 entries.
0062. Checksum list excludes itself.
0063. Checksum entries are sorted by UTF-8 filename bytes.
0064. Each checksum digest has 64 lowercase hexadecimal characters.
0065. Two generated corpora have identical relative file sets.
0066. Two generated corpora have identical archive bytes.
0067. Two generated corpora have identical fixtures.json bytes.
0068. Two generated corpora have identical corpus.sha256 bytes.
0069. Two generated corpora have identical total byte count.
0070. Corpus generation is independent of current time.
0071. Corpus generation is independent of timezone.
0072. Corpus generation is independent of locale.
0073. Corpus generation is independent of hostname and username.
0074. Corpus generation is independent of temporary-root spelling.
0075. Corpus generation is independent of Python hash randomization.
0076. Corpus generation is independent of directory enumeration order.
0077. Corpus generation is independent of zlib compressor version.
0078. Corpus generation is independent of host tar implementation.
0079. Harness metadata parser requires exact top-level keys.
0080. Harness metadata parser rejects Boolean numeric fields.
0081. Harness metadata parser requires exact ordered IDs.
0082. Harness metadata parser rejects duplicate archive names.
0083. Harness metadata parser requires safe single-component archive names.
0084. Harness metadata parser requires complete lowercase SHA-256 values.
0085. Harness metadata parser requires rejected codes in 1 through 16.
0086. Harness metadata parser requires nonempty safe field paths.
0087. Harness links the unchanged production validator source.
0088. Harness does not link production artifact-verifier implementation.
0089. Harness provides only the required verified-set implementation.
0090. Harness invokes the validator exactly once per fixture.
0091. Harness performs no retry or fallback parsing.
0092. Harness performs no extraction.
0093. Harness performs no tar listing.
0094. Harness snapshots the corpus before the suite.
0095. Harness snapshots the corpus after every fixture.
0096. Harness snapshots the corpus after the complete suite.
0097. Harness ignores atime but compares all required identity and byte fields.
0098. Workflow fixture step follows the static audit.
0099. Workflow fixture step precedes dependency installation.
0100. Workflow uses set -euo pipefail.
0101. Workflow compiles PXBackupArchiveValidator.m directly.
0102. Workflow compiles only the authorized harness beside the validator.
0103. Workflow runs all 86 fixtures.
0104. Workflow contains no failure bypass.
0105. Workflow exact SHA-256 matches the required value.
0106. Static self-tests pass 49/49.
0107. Repository guards pass 1703/1703.
0108. Repository guard delta is exactly four.
0109. Harness BYTES environment guard passes.
0110. Harness UTF8 environment guard passes.
0111. Harness NUL environment guard passes.
0112. Harness CONFLICT environment guard passes.
0113. Python generator adds no C-family repository guard.
0114. Report adds no C-family repository guard.
0115. Workflow edit adds no new repository-file guard.
0116. Tests directory remains included by static-audit discovery.
0117. Repeated static self-test output is byte-identical.
0118. Repeated repository audit output is byte-identical.
0119. Audit script protected hash remains unchanged.
0120. GitHub Actions remains pending until a remote run exists.
0121. Apple Objective-C compile is not claimed on Windows.
0122. Harness 86/86 runtime success is not claimed before macOS execution.
0123. Runtime no-mutation success is not claimed before macOS execution.
0124. No push is performed.
0125. A001 ID and archive ordering are exact.
0126. A001 archive name is exactly A001.tar.gz.
0127. A001 disposition is accepted.
0128. A001 declared compressed size and digest match generated bytes.
0129. A001 requires nonnil result and nil error.
0130. A001 result archiveNames equals the one archive name.
0131. A001 containsArchiveName returns YES for the fixture archive.
0132. A001 containsArchiveName returns NO for unknown.tar.gz.
0133. A001 member count equals 2.
0134. A001 regular-file byte total equals 3.
0135. A001 result copyWithZone preserves identity.
0136. A001 leaves the complete fixture-root snapshot unchanged.
0137. A002 ID and archive ordering are exact.
0138. A002 archive name is exactly A002.tar.gz.
0139. A002 disposition is accepted.
0140. A002 declared compressed size and digest match generated bytes.
0141. A002 requires nonnil result and nil error.
0142. A002 result archiveNames equals the one archive name.
0143. A002 containsArchiveName returns YES for the fixture archive.
0144. A002 containsArchiveName returns NO for unknown.tar.gz.
0145. A002 member count equals 1.
0146. A002 regular-file byte total equals 1.
0147. A002 result copyWithZone preserves identity.
0148. A002 leaves the complete fixture-root snapshot unchanged.
0149. A003 ID and archive ordering are exact.
0150. A003 archive name is exactly A003.tar.gz.
0151. A003 disposition is accepted.
0152. A003 declared compressed size and digest match generated bytes.
0153. A003 requires nonnil result and nil error.
0154. A003 result archiveNames equals the one archive name.
0155. A003 containsArchiveName returns YES for the fixture archive.
0156. A003 containsArchiveName returns NO for unknown.tar.gz.
0157. A003 member count equals 1.
0158. A003 regular-file byte total equals 1.
0159. A003 result copyWithZone preserves identity.
0160. A003 leaves the complete fixture-root snapshot unchanged.
0161. A004 ID and archive ordering are exact.
0162. A004 archive name is exactly A004.tar.gz.
0163. A004 disposition is accepted.
0164. A004 declared compressed size and digest match generated bytes.
0165. A004 requires nonnil result and nil error.
0166. A004 result archiveNames equals the one archive name.
0167. A004 containsArchiveName returns YES for the fixture archive.
0168. A004 containsArchiveName returns NO for unknown.tar.gz.
0169. A004 member count equals 1.
0170. A004 regular-file byte total equals 1.
0171. A004 result copyWithZone preserves identity.
0172. A004 leaves the complete fixture-root snapshot unchanged.
0173. A005 ID and archive ordering are exact.
0174. A005 archive name is exactly A005.tar.gz.
0175. A005 disposition is accepted.
0176. A005 declared compressed size and digest match generated bytes.
0177. A005 requires nonnil result and nil error.
0178. A005 result archiveNames equals the one archive name.
0179. A005 containsArchiveName returns YES for the fixture archive.
0180. A005 containsArchiveName returns NO for unknown.tar.gz.
0181. A005 member count equals 2.
0182. A005 regular-file byte total equals 1.
0183. A005 result copyWithZone preserves identity.
0184. A005 leaves the complete fixture-root snapshot unchanged.
0185. A006 ID and archive ordering are exact.
0186. A006 archive name is exactly A006.tar.gz.
0187. A006 disposition is accepted.
0188. A006 declared compressed size and digest match generated bytes.
0189. A006 requires nonnil result and nil error.
0190. A006 result archiveNames equals the one archive name.
0191. A006 containsArchiveName returns YES for the fixture archive.
0192. A006 containsArchiveName returns NO for unknown.tar.gz.
0193. A006 member count equals 1.
0194. A006 regular-file byte total equals 1.
0195. A006 result copyWithZone preserves identity.
0196. A006 leaves the complete fixture-root snapshot unchanged.
0197. A007 ID and archive ordering are exact.
0198. A007 archive name is exactly A007.tar.gz.
0199. A007 disposition is accepted.
0200. A007 declared compressed size and digest match generated bytes.
0201. A007 requires nonnil result and nil error.
0202. A007 result archiveNames equals the one archive name.
0203. A007 containsArchiveName returns YES for the fixture archive.
0204. A007 containsArchiveName returns NO for unknown.tar.gz.
0205. A007 member count equals 1.
0206. A007 regular-file byte total equals 0.
0207. A007 result copyWithZone preserves identity.
0208. A007 leaves the complete fixture-root snapshot unchanged.
0209. A008 ID and archive ordering are exact.
0210. A008 archive name is exactly A008.tar.gz.
0211. A008 disposition is accepted.
0212. A008 declared compressed size and digest match generated bytes.
0213. A008 requires nonnil result and nil error.
0214. A008 result archiveNames equals the one archive name.
0215. A008 containsArchiveName returns YES for the fixture archive.
0216. A008 containsArchiveName returns NO for unknown.tar.gz.
0217. A008 member count equals 1.
0218. A008 regular-file byte total equals 0.
0219. A008 result copyWithZone preserves identity.
0220. A008 leaves the complete fixture-root snapshot unchanged.
0221. A009 ID and archive ordering are exact.
0222. A009 archive name is exactly A009.tar.gz.
0223. A009 disposition is accepted.
0224. A009 declared compressed size and digest match generated bytes.
0225. A009 requires nonnil result and nil error.
0226. A009 result archiveNames equals the one archive name.
0227. A009 containsArchiveName returns YES for the fixture archive.
0228. A009 containsArchiveName returns NO for unknown.tar.gz.
0229. A009 member count equals 1.
0230. A009 regular-file byte total equals 1.
0231. A009 result copyWithZone preserves identity.
0232. A009 leaves the complete fixture-root snapshot unchanged.
0233. A010 ID and archive ordering are exact.
0234. A010 archive name is exactly A010.tar.gz.
0235. A010 disposition is accepted.
0236. A010 declared compressed size and digest match generated bytes.
0237. A010 requires nonnil result and nil error.
0238. A010 result archiveNames equals the one archive name.
0239. A010 containsArchiveName returns YES for the fixture archive.
0240. A010 containsArchiveName returns NO for unknown.tar.gz.
0241. A010 member count equals 1.
0242. A010 regular-file byte total equals 0.
0243. A010 result copyWithZone preserves identity.
0244. A010 leaves the complete fixture-root snapshot unchanged.
0245. A011 ID and archive ordering are exact.
0246. A011 archive name is exactly A011.tar.gz.
0247. A011 disposition is accepted.
0248. A011 declared compressed size and digest match generated bytes.
0249. A011 requires nonnil result and nil error.
0250. A011 result archiveNames equals the one archive name.
0251. A011 containsArchiveName returns YES for the fixture archive.
0252. A011 containsArchiveName returns NO for unknown.tar.gz.
0253. A011 member count equals 1.
0254. A011 regular-file byte total equals 3.
0255. A011 result copyWithZone preserves identity.
0256. A011 leaves the complete fixture-root snapshot unchanged.
0257. A012 ID and archive ordering are exact.
0258. A012 archive name is exactly A012.tar.gz.
0259. A012 disposition is accepted.
0260. A012 declared compressed size and digest match generated bytes.
0261. A012 requires nonnil result and nil error.
0262. A012 result archiveNames equals the one archive name.
0263. A012 containsArchiveName returns YES for the fixture archive.
0264. A012 containsArchiveName returns NO for unknown.tar.gz.
0265. A012 member count equals 1.
0266. A012 regular-file byte total equals 1.
0267. A012 result copyWithZone preserves identity.
0268. A012 leaves the complete fixture-root snapshot unchanged.
0269. A013 ID and archive ordering are exact.
0270. A013 archive name is exactly A013.tar.gz.
0271. A013 disposition is accepted.
0272. A013 declared compressed size and digest match generated bytes.
0273. A013 requires nonnil result and nil error.
0274. A013 result archiveNames equals the one archive name.
0275. A013 containsArchiveName returns YES for the fixture archive.
0276. A013 containsArchiveName returns NO for unknown.tar.gz.
0277. A013 member count equals 1.
0278. A013 regular-file byte total equals 1.
0279. A013 result copyWithZone preserves identity.
0280. A013 leaves the complete fixture-root snapshot unchanged.
0281. A014 ID and archive ordering are exact.
0282. A014 archive name is exactly A014.tar.gz.
0283. A014 disposition is accepted.
0284. A014 declared compressed size and digest match generated bytes.
0285. A014 requires nonnil result and nil error.
0286. A014 result archiveNames equals the one archive name.
0287. A014 containsArchiveName returns YES for the fixture archive.
0288. A014 containsArchiveName returns NO for unknown.tar.gz.
0289. A014 member count equals 1.
0290. A014 regular-file byte total equals 1.
0291. A014 result copyWithZone preserves identity.
0292. A014 leaves the complete fixture-root snapshot unchanged.
0293. A015 ID and archive ordering are exact.
0294. A015 archive name is exactly A015.tar.gz.
0295. A015 disposition is accepted.
0296. A015 declared compressed size and digest match generated bytes.
0297. A015 requires nonnil result and nil error.
0298. A015 result archiveNames equals the one archive name.
0299. A015 containsArchiveName returns YES for the fixture archive.
0300. A015 containsArchiveName returns NO for unknown.tar.gz.
0301. A015 member count equals 1.
0302. A015 regular-file byte total equals 0.
0303. A015 result copyWithZone preserves identity.
0304. A015 leaves the complete fixture-root snapshot unchanged.
0305. A016 ID and archive ordering are exact.
0306. A016 archive name is exactly A016.tar.gz.
0307. A016 disposition is accepted.
0308. A016 declared compressed size and digest match generated bytes.
0309. A016 requires nonnil result and nil error.
0310. A016 result archiveNames equals the one archive name.
0311. A016 containsArchiveName returns YES for the fixture archive.
0312. A016 containsArchiveName returns NO for unknown.tar.gz.
0313. A016 member count equals 1.
0314. A016 regular-file byte total equals 0.
0315. A016 result copyWithZone preserves identity.
0316. A016 leaves the complete fixture-root snapshot unchanged.
0317. A017 ID and archive ordering are exact.
0318. A017 archive name is exactly A017.tar.gz.
0319. A017 disposition is accepted.
0320. A017 declared compressed size and digest match generated bytes.
0321. A017 requires nonnil result and nil error.
0322. A017 result archiveNames equals the one archive name.
0323. A017 containsArchiveName returns YES for the fixture archive.
0324. A017 containsArchiveName returns NO for unknown.tar.gz.
0325. A017 member count equals 1.
0326. A017 regular-file byte total equals 0.
0327. A017 result copyWithZone preserves identity.
0328. A017 leaves the complete fixture-root snapshot unchanged.
0329. A018 ID and archive ordering are exact.
0330. A018 archive name is exactly A018.tar.gz.
0331. A018 disposition is accepted.
0332. A018 declared compressed size and digest match generated bytes.
0333. A018 requires nonnil result and nil error.
0334. A018 result archiveNames equals the one archive name.
0335. A018 containsArchiveName returns YES for the fixture archive.
0336. A018 containsArchiveName returns NO for unknown.tar.gz.
0337. A018 member count equals 1.
0338. A018 regular-file byte total equals 0.
0339. A018 result copyWithZone preserves identity.
0340. A018 leaves the complete fixture-root snapshot unchanged.
0341. A019 ID and archive ordering are exact.
0342. A019 archive name is exactly A019.tar.gz.
0343. A019 disposition is accepted.
0344. A019 declared compressed size and digest match generated bytes.
0345. A019 requires nonnil result and nil error.
0346. A019 result archiveNames equals the one archive name.
0347. A019 containsArchiveName returns YES for the fixture archive.
0348. A019 containsArchiveName returns NO for unknown.tar.gz.
0349. A019 member count equals 1.
0350. A019 regular-file byte total equals 1.
0351. A019 result copyWithZone preserves identity.
0352. A019 leaves the complete fixture-root snapshot unchanged.
0353. A020 ID and archive ordering are exact.
0354. A020 archive name is exactly A020.tar.gz.
0355. A020 disposition is accepted.
0356. A020 declared compressed size and digest match generated bytes.
0357. A020 requires nonnil result and nil error.
0358. A020 result archiveNames equals the one archive name.
0359. A020 containsArchiveName returns YES for the fixture archive.
0360. A020 containsArchiveName returns NO for unknown.tar.gz.
0361. A020 member count equals 2.
0362. A020 regular-file byte total equals 1.
0363. A020 result copyWithZone preserves identity.
0364. A020 leaves the complete fixture-root snapshot unchanged.
0365. R001 ID and archive ordering are exact.
0366. R001 archive name is exactly R001.tar.gz.
0367. R001 disposition is rejected.
0368. R001 declaration metadata reaches the intended validation branch.
0369. R001 requires a nil result.
0370. R001 requires a nonnil NSError.
0371. R001 error domain equals PXBackupArchiveValidatorErrorDomain.
0372. R001 error code equals 8 (UnsafeEntryPath).
0373. R001 exact field path equals $.artifacts[0].members[0].path.
0374. R001 userInfo keys are exactly description and field path.
0375. R001 description is a nonempty generic NSString.
0376. R001 error values contain no forbidden raw fixture token.
0377. R001 leaves the complete fixture-root snapshot unchanged.
0378. R002 ID and archive ordering are exact.
0379. R002 archive name is exactly R002.tar.gz.
0380. R002 disposition is rejected.
0381. R002 declaration metadata reaches the intended validation branch.
0382. R002 requires a nil result.
0383. R002 requires a nonnil NSError.
0384. R002 error domain equals PXBackupArchiveValidatorErrorDomain.
0385. R002 error code equals 8 (UnsafeEntryPath).
0386. R002 exact field path equals $.artifacts[0].members[0].path.
0387. R002 userInfo keys are exactly description and field path.
0388. R002 description is a nonempty generic NSString.
0389. R002 error values contain no forbidden raw fixture token.
0390. R002 leaves the complete fixture-root snapshot unchanged.
0391. R003 ID and archive ordering are exact.
0392. R003 archive name is exactly R003.tar.gz.
0393. R003 disposition is rejected.
0394. R003 declaration metadata reaches the intended validation branch.
0395. R003 requires a nil result.
0396. R003 requires a nonnil NSError.
0397. R003 error domain equals PXBackupArchiveValidatorErrorDomain.
0398. R003 error code equals 8 (UnsafeEntryPath).
0399. R003 exact field path equals $.artifacts[0].members[0].path.
0400. R003 userInfo keys are exactly description and field path.
0401. R003 description is a nonempty generic NSString.
0402. R003 error values contain no forbidden raw fixture token.
0403. R003 leaves the complete fixture-root snapshot unchanged.
0404. R004 ID and archive ordering are exact.
0405. R004 archive name is exactly R004.tar.gz.
0406. R004 disposition is rejected.
0407. R004 declaration metadata reaches the intended validation branch.
0408. R004 requires a nil result.
0409. R004 requires a nonnil NSError.
0410. R004 error domain equals PXBackupArchiveValidatorErrorDomain.
0411. R004 error code equals 8 (UnsafeEntryPath).
0412. R004 exact field path equals $.artifacts[0].members[0].path.
0413. R004 userInfo keys are exactly description and field path.
0414. R004 description is a nonempty generic NSString.
0415. R004 error values contain no forbidden raw fixture token.
0416. R004 leaves the complete fixture-root snapshot unchanged.
0417. R005 ID and archive ordering are exact.
0418. R005 archive name is exactly R005.tar.gz.
0419. R005 disposition is rejected.
0420. R005 declaration metadata reaches the intended validation branch.
0421. R005 requires a nil result.
0422. R005 requires a nonnil NSError.
0423. R005 error domain equals PXBackupArchiveValidatorErrorDomain.
0424. R005 error code equals 8 (UnsafeEntryPath).
0425. R005 exact field path equals $.artifacts[0].members[0].path.
0426. R005 userInfo keys are exactly description and field path.
0427. R005 description is a nonempty generic NSString.
0428. R005 error values contain no forbidden raw fixture token.
0429. R005 leaves the complete fixture-root snapshot unchanged.
0430. R006 ID and archive ordering are exact.
0431. R006 archive name is exactly R006.tar.gz.
0432. R006 disposition is rejected.
0433. R006 declaration metadata reaches the intended validation branch.
0434. R006 requires a nil result.
0435. R006 requires a nonnil NSError.
0436. R006 error domain equals PXBackupArchiveValidatorErrorDomain.
0437. R006 error code equals 8 (UnsafeEntryPath).
0438. R006 exact field path equals $.artifacts[0].members[0].path.
0439. R006 userInfo keys are exactly description and field path.
0440. R006 description is a nonempty generic NSString.
0441. R006 error values contain no forbidden raw fixture token.
0442. R006 leaves the complete fixture-root snapshot unchanged.
0443. R007 ID and archive ordering are exact.
0444. R007 archive name is exactly R007.tar.gz.
0445. R007 disposition is rejected.
0446. R007 declaration metadata reaches the intended validation branch.
0447. R007 requires a nil result.
0448. R007 requires a nonnil NSError.
0449. R007 error domain equals PXBackupArchiveValidatorErrorDomain.
0450. R007 error code equals 8 (UnsafeEntryPath).
0451. R007 exact field path equals $.artifacts[0].members[0].path.
0452. R007 userInfo keys are exactly description and field path.
0453. R007 description is a nonempty generic NSString.
0454. R007 error values contain no forbidden raw fixture token.
0455. R007 leaves the complete fixture-root snapshot unchanged.
0456. R008 ID and archive ordering are exact.
0457. R008 archive name is exactly R008.tar.gz.
0458. R008 disposition is rejected.
0459. R008 declaration metadata reaches the intended validation branch.
0460. R008 requires a nil result.
0461. R008 requires a nonnil NSError.
0462. R008 error domain equals PXBackupArchiveValidatorErrorDomain.
0463. R008 error code equals 8 (UnsafeEntryPath).
0464. R008 exact field path equals $.artifacts[0].members[0].path.
0465. R008 userInfo keys are exactly description and field path.
0466. R008 description is a nonempty generic NSString.
0467. R008 error values contain no forbidden raw fixture token.
0468. R008 leaves the complete fixture-root snapshot unchanged.
0469. R009 ID and archive ordering are exact.
0470. R009 archive name is exactly R009.tar.gz.
0471. R009 disposition is rejected.
0472. R009 declaration metadata reaches the intended validation branch.
0473. R009 requires a nil result.
0474. R009 requires a nonnil NSError.
0475. R009 error domain equals PXBackupArchiveValidatorErrorDomain.
0476. R009 error code equals 8 (UnsafeEntryPath).
0477. R009 exact field path equals $.artifacts[0].members[0].path.
0478. R009 userInfo keys are exactly description and field path.
0479. R009 description is a nonempty generic NSString.
0480. R009 error values contain no forbidden raw fixture token.
0481. R009 leaves the complete fixture-root snapshot unchanged.
0482. R010 ID and archive ordering are exact.
0483. R010 archive name is exactly R010.tar.gz.
0484. R010 disposition is rejected.
0485. R010 declaration metadata reaches the intended validation branch.
0486. R010 requires a nil result.
0487. R010 requires a nonnil NSError.
0488. R010 error domain equals PXBackupArchiveValidatorErrorDomain.
0489. R010 error code equals 8 (UnsafeEntryPath).
0490. R010 exact field path equals $.artifacts[0].members[0].path.
0491. R010 userInfo keys are exactly description and field path.
0492. R010 description is a nonempty generic NSString.
0493. R010 error values contain no forbidden raw fixture token.
0494. R010 leaves the complete fixture-root snapshot unchanged.
0495. R011 ID and archive ordering are exact.
0496. R011 archive name is exactly R011.tar.gz.
0497. R011 disposition is rejected.
0498. R011 declaration metadata reaches the intended validation branch.
0499. R011 requires a nil result.
0500. R011 requires a nonnil NSError.
0501. R011 error domain equals PXBackupArchiveValidatorErrorDomain.
0502. R011 error code equals 12 (LimitExceeded).
0503. R011 exact field path equals $.artifacts[0].members[1].path.
0504. R011 userInfo keys are exactly description and field path.
0505. R011 description is a nonempty generic NSString.
0506. R011 error values contain no forbidden raw fixture token.
0507. R011 leaves the complete fixture-root snapshot unchanged.
0508. R012 ID and archive ordering are exact.
0509. R012 archive name is exactly R012.tar.gz.
0510. R012 disposition is rejected.
0511. R012 declaration metadata reaches the intended validation branch.
0512. R012 requires a nil result.
0513. R012 requires a nonnil NSError.
0514. R012 error domain equals PXBackupArchiveValidatorErrorDomain.
0515. R012 error code equals 12 (LimitExceeded).
0516. R012 exact field path equals $.artifacts[0].members[1].path.
0517. R012 userInfo keys are exactly description and field path.
0518. R012 description is a nonempty generic NSString.
0519. R012 error values contain no forbidden raw fixture token.
0520. R012 leaves the complete fixture-root snapshot unchanged.
0521. R013 ID and archive ordering are exact.
0522. R013 archive name is exactly R013.tar.gz.
0523. R013 disposition is rejected.
0524. R013 declaration metadata reaches the intended validation branch.
0525. R013 requires a nil result.
0526. R013 requires a nonnil NSError.
0527. R013 error domain equals PXBackupArchiveValidatorErrorDomain.
0528. R013 error code equals 9 (DuplicateEntry).
0529. R013 exact field path equals $.artifacts[0].members[1].path.
0530. R013 userInfo keys are exactly description and field path.
0531. R013 description is a nonempty generic NSString.
0532. R013 error values contain no forbidden raw fixture token.
0533. R013 leaves the complete fixture-root snapshot unchanged.
0534. R014 ID and archive ordering are exact.
0535. R014 archive name is exactly R014.tar.gz.
0536. R014 disposition is rejected.
0537. R014 declaration metadata reaches the intended validation branch.
0538. R014 requires a nil result.
0539. R014 requires a nonnil NSError.
0540. R014 error domain equals PXBackupArchiveValidatorErrorDomain.
0541. R014 error code equals 9 (DuplicateEntry).
0542. R014 exact field path equals $.artifacts[0].members[1].path.
0543. R014 userInfo keys are exactly description and field path.
0544. R014 description is a nonempty generic NSString.
0545. R014 error values contain no forbidden raw fixture token.
0546. R014 leaves the complete fixture-root snapshot unchanged.
0547. R015 ID and archive ordering are exact.
0548. R015 archive name is exactly R015.tar.gz.
0549. R015 disposition is rejected.
0550. R015 declaration metadata reaches the intended validation branch.
0551. R015 requires a nil result.
0552. R015 requires a nonnil NSError.
0553. R015 error domain equals PXBackupArchiveValidatorErrorDomain.
0554. R015 error code equals 9 (DuplicateEntry).
0555. R015 exact field path equals $.artifacts[0].members[1].path.
0556. R015 userInfo keys are exactly description and field path.
0557. R015 description is a nonempty generic NSString.
0558. R015 error values contain no forbidden raw fixture token.
0559. R015 leaves the complete fixture-root snapshot unchanged.
0560. R016 ID and archive ordering are exact.
0561. R016 archive name is exactly R016.tar.gz.
0562. R016 disposition is rejected.
0563. R016 declaration metadata reaches the intended validation branch.
0564. R016 requires a nil result.
0565. R016 requires a nonnil NSError.
0566. R016 error domain equals PXBackupArchiveValidatorErrorDomain.
0567. R016 error code equals 9 (DuplicateEntry).
0568. R016 exact field path equals $.artifacts[0].members[1].path.
0569. R016 userInfo keys are exactly description and field path.
0570. R016 description is a nonempty generic NSString.
0571. R016 error values contain no forbidden raw fixture token.
0572. R016 leaves the complete fixture-root snapshot unchanged.
0573. R017 ID and archive ordering are exact.
0574. R017 archive name is exactly R017.tar.gz.
0575. R017 disposition is rejected.
0576. R017 declaration metadata reaches the intended validation branch.
0577. R017 requires a nil result.
0578. R017 requires a nonnil NSError.
0579. R017 error domain equals PXBackupArchiveValidatorErrorDomain.
0580. R017 error code equals 9 (DuplicateEntry).
0581. R017 exact field path equals $.artifacts[0].members[1].path.
0582. R017 userInfo keys are exactly description and field path.
0583. R017 description is a nonempty generic NSString.
0584. R017 error values contain no forbidden raw fixture token.
0585. R017 leaves the complete fixture-root snapshot unchanged.
0586. R018 ID and archive ordering are exact.
0587. R018 archive name is exactly R018.tar.gz.
0588. R018 disposition is rejected.
0589. R018 declaration metadata reaches the intended validation branch.
0590. R018 requires a nil result.
0591. R018 requires a nonnil NSError.
0592. R018 error domain equals PXBackupArchiveValidatorErrorDomain.
0593. R018 error code equals 10 (UnsupportedEntryType).
0594. R018 exact field path equals $.artifacts[0].members[0].type.
0595. R018 userInfo keys are exactly description and field path.
0596. R018 description is a nonempty generic NSString.
0597. R018 error values contain no forbidden raw fixture token.
0598. R018 leaves the complete fixture-root snapshot unchanged.
0599. R019 ID and archive ordering are exact.
0600. R019 archive name is exactly R019.tar.gz.
0601. R019 disposition is rejected.
0602. R019 declaration metadata reaches the intended validation branch.
0603. R019 requires a nil result.
0604. R019 requires a nonnil NSError.
0605. R019 error domain equals PXBackupArchiveValidatorErrorDomain.
0606. R019 error code equals 10 (UnsupportedEntryType).
0607. R019 exact field path equals $.artifacts[0].members[0].type.
0608. R019 userInfo keys are exactly description and field path.
0609. R019 description is a nonempty generic NSString.
0610. R019 error values contain no forbidden raw fixture token.
0611. R019 leaves the complete fixture-root snapshot unchanged.
0612. R020 ID and archive ordering are exact.
0613. R020 archive name is exactly R020.tar.gz.
0614. R020 disposition is rejected.
0615. R020 declaration metadata reaches the intended validation branch.
0616. R020 requires a nil result.
0617. R020 requires a nonnil NSError.
0618. R020 error domain equals PXBackupArchiveValidatorErrorDomain.
0619. R020 error code equals 10 (UnsupportedEntryType).
0620. R020 exact field path equals $.artifacts[0].members[0].type.
0621. R020 userInfo keys are exactly description and field path.
0622. R020 description is a nonempty generic NSString.
0623. R020 error values contain no forbidden raw fixture token.
0624. R020 leaves the complete fixture-root snapshot unchanged.
0625. R021 ID and archive ordering are exact.
0626. R021 archive name is exactly R021.tar.gz.
0627. R021 disposition is rejected.
0628. R021 declaration metadata reaches the intended validation branch.
0629. R021 requires a nil result.
0630. R021 requires a nonnil NSError.
0631. R021 error domain equals PXBackupArchiveValidatorErrorDomain.
0632. R021 error code equals 10 (UnsupportedEntryType).
0633. R021 exact field path equals $.artifacts[0].members[0].type.
0634. R021 userInfo keys are exactly description and field path.
0635. R021 description is a nonempty generic NSString.
0636. R021 error values contain no forbidden raw fixture token.
0637. R021 leaves the complete fixture-root snapshot unchanged.
0638. R022 ID and archive ordering are exact.
0639. R022 archive name is exactly R022.tar.gz.
0640. R022 disposition is rejected.
0641. R022 declaration metadata reaches the intended validation branch.
0642. R022 requires a nil result.
0643. R022 requires a nonnil NSError.
0644. R022 error domain equals PXBackupArchiveValidatorErrorDomain.
0645. R022 error code equals 10 (UnsupportedEntryType).
0646. R022 exact field path equals $.artifacts[0].members[0].type.
0647. R022 userInfo keys are exactly description and field path.
0648. R022 description is a nonempty generic NSString.
0649. R022 error values contain no forbidden raw fixture token.
0650. R022 leaves the complete fixture-root snapshot unchanged.
0651. R023 ID and archive ordering are exact.
0652. R023 archive name is exactly R023.tar.gz.
0653. R023 disposition is rejected.
0654. R023 declaration metadata reaches the intended validation branch.
0655. R023 requires a nil result.
0656. R023 requires a nonnil NSError.
0657. R023 error domain equals PXBackupArchiveValidatorErrorDomain.
0658. R023 error code equals 10 (UnsupportedEntryType).
0659. R023 exact field path equals $.artifacts[0].members[0].type.
0660. R023 userInfo keys are exactly description and field path.
0661. R023 description is a nonempty generic NSString.
0662. R023 error values contain no forbidden raw fixture token.
0663. R023 leaves the complete fixture-root snapshot unchanged.
0664. R024 ID and archive ordering are exact.
0665. R024 archive name is exactly R024.tar.gz.
0666. R024 disposition is rejected.
0667. R024 declaration metadata reaches the intended validation branch.
0668. R024 requires a nil result.
0669. R024 requires a nonnil NSError.
0670. R024 error domain equals PXBackupArchiveValidatorErrorDomain.
0671. R024 error code equals 10 (UnsupportedEntryType).
0672. R024 exact field path equals $.artifacts[0].members[0].type.
0673. R024 userInfo keys are exactly description and field path.
0674. R024 description is a nonempty generic NSString.
0675. R024 error values contain no forbidden raw fixture token.
0676. R024 leaves the complete fixture-root snapshot unchanged.
0677. R025 ID and archive ordering are exact.
0678. R025 archive name is exactly R025.tar.gz.
0679. R025 disposition is rejected.
0680. R025 declaration metadata reaches the intended validation branch.
0681. R025 requires a nil result.
0682. R025 requires a nonnil NSError.
0683. R025 error domain equals PXBackupArchiveValidatorErrorDomain.
0684. R025 error code equals 10 (UnsupportedEntryType).
0685. R025 exact field path equals $.artifacts[0].members[0].type.
0686. R025 userInfo keys are exactly description and field path.
0687. R025 description is a nonempty generic NSString.
0688. R025 error values contain no forbidden raw fixture token.
0689. R025 leaves the complete fixture-root snapshot unchanged.
0690. R026 ID and archive ordering are exact.
0691. R026 archive name is exactly R026.tar.gz.
0692. R026 disposition is rejected.
0693. R026 declaration metadata reaches the intended validation branch.
0694. R026 requires a nil result.
0695. R026 requires a nonnil NSError.
0696. R026 error domain equals PXBackupArchiveValidatorErrorDomain.
0697. R026 error code equals 10 (UnsupportedEntryType).
0698. R026 exact field path equals $.artifacts[0].members[0].type.
0699. R026 userInfo keys are exactly description and field path.
0700. R026 description is a nonempty generic NSString.
0701. R026 error values contain no forbidden raw fixture token.
0702. R026 leaves the complete fixture-root snapshot unchanged.
0703. R027 ID and archive ordering are exact.
0704. R027 archive name is exactly R027.tar.gz.
0705. R027 disposition is rejected.
0706. R027 declaration metadata reaches the intended validation branch.
0707. R027 requires a nil result.
0708. R027 requires a nonnil NSError.
0709. R027 error domain equals PXBackupArchiveValidatorErrorDomain.
0710. R027 error code equals 10 (UnsupportedEntryType).
0711. R027 exact field path equals $.artifacts[0].members[0].type.
0712. R027 userInfo keys are exactly description and field path.
0713. R027 description is a nonempty generic NSString.
0714. R027 error values contain no forbidden raw fixture token.
0715. R027 leaves the complete fixture-root snapshot unchanged.
0716. R028 ID and archive ordering are exact.
0717. R028 archive name is exactly R028.tar.gz.
0718. R028 disposition is rejected.
0719. R028 declaration metadata reaches the intended validation branch.
0720. R028 requires a nil result.
0721. R028 requires a nonnil NSError.
0722. R028 error domain equals PXBackupArchiveValidatorErrorDomain.
0723. R028 error code equals 7 (InvalidHeader).
0724. R028 exact field path equals $.artifacts[0].members[0].type.
0725. R028 userInfo keys are exactly description and field path.
0726. R028 description is a nonempty generic NSString.
0727. R028 error values contain no forbidden raw fixture token.
0728. R028 leaves the complete fixture-root snapshot unchanged.
0729. R029 ID and archive ordering are exact.
0730. R029 archive name is exactly R029.tar.gz.
0731. R029 disposition is rejected.
0732. R029 declaration metadata reaches the intended validation branch.
0733. R029 requires a nil result.
0734. R029 requires a nonnil NSError.
0735. R029 error domain equals PXBackupArchiveValidatorErrorDomain.
0736. R029 error code equals 7 (InvalidHeader).
0737. R029 exact field path equals $.artifacts[0].members[0].
0738. R029 userInfo keys are exactly description and field path.
0739. R029 description is a nonempty generic NSString.
0740. R029 error values contain no forbidden raw fixture token.
0741. R029 leaves the complete fixture-root snapshot unchanged.
0742. R030 ID and archive ordering are exact.
0743. R030 archive name is exactly R030.tar.gz.
0744. R030 disposition is rejected.
0745. R030 declaration metadata reaches the intended validation branch.
0746. R030 requires a nil result.
0747. R030 requires a nonnil NSError.
0748. R030 error domain equals PXBackupArchiveValidatorErrorDomain.
0749. R030 error code equals 7 (InvalidHeader).
0750. R030 exact field path equals $.artifacts[0].members[0].
0751. R030 userInfo keys are exactly description and field path.
0752. R030 description is a nonempty generic NSString.
0753. R030 error values contain no forbidden raw fixture token.
0754. R030 leaves the complete fixture-root snapshot unchanged.
0755. R031 ID and archive ordering are exact.
0756. R031 archive name is exactly R031.tar.gz.
0757. R031 disposition is rejected.
0758. R031 declaration metadata reaches the intended validation branch.
0759. R031 requires a nil result.
0760. R031 requires a nonnil NSError.
0761. R031 error domain equals PXBackupArchiveValidatorErrorDomain.
0762. R031 error code equals 7 (InvalidHeader).
0763. R031 exact field path equals $.artifacts[0].members[0].
0764. R031 userInfo keys are exactly description and field path.
0765. R031 description is a nonempty generic NSString.
0766. R031 error values contain no forbidden raw fixture token.
0767. R031 leaves the complete fixture-root snapshot unchanged.
0768. R032 ID and archive ordering are exact.
0769. R032 archive name is exactly R032.tar.gz.
0770. R032 disposition is rejected.
0771. R032 declaration metadata reaches the intended validation branch.
0772. R032 requires a nil result.
0773. R032 requires a nonnil NSError.
0774. R032 error domain equals PXBackupArchiveValidatorErrorDomain.
0775. R032 error code equals 7 (InvalidHeader).
0776. R032 exact field path equals $.artifacts[0].members[0].
0777. R032 userInfo keys are exactly description and field path.
0778. R032 description is a nonempty generic NSString.
0779. R032 error values contain no forbidden raw fixture token.
0780. R032 leaves the complete fixture-root snapshot unchanged.
0781. R033 ID and archive ordering are exact.
0782. R033 archive name is exactly R033.tar.gz.
0783. R033 disposition is rejected.
0784. R033 declaration metadata reaches the intended validation branch.
0785. R033 requires a nil result.
0786. R033 requires a nonnil NSError.
0787. R033 error domain equals PXBackupArchiveValidatorErrorDomain.
0788. R033 error code equals 7 (InvalidHeader).
0789. R033 exact field path equals $.artifacts[0].members[0].
0790. R033 userInfo keys are exactly description and field path.
0791. R033 description is a nonempty generic NSString.
0792. R033 error values contain no forbidden raw fixture token.
0793. R033 leaves the complete fixture-root snapshot unchanged.
0794. R034 ID and archive ordering are exact.
0795. R034 archive name is exactly R034.tar.gz.
0796. R034 disposition is rejected.
0797. R034 declaration metadata reaches the intended validation branch.
0798. R034 requires a nil result.
0799. R034 requires a nonnil NSError.
0800. R034 error domain equals PXBackupArchiveValidatorErrorDomain.
0801. R034 error code equals 7 (InvalidHeader).
0802. R034 exact field path equals $.artifacts[0].members[0].
0803. R034 userInfo keys are exactly description and field path.
0804. R034 description is a nonempty generic NSString.
0805. R034 error values contain no forbidden raw fixture token.
0806. R034 leaves the complete fixture-root snapshot unchanged.
0807. R035 ID and archive ordering are exact.
0808. R035 archive name is exactly R035.tar.gz.
0809. R035 disposition is rejected.
0810. R035 declaration metadata reaches the intended validation branch.
0811. R035 requires a nil result.
0812. R035 requires a nonnil NSError.
0813. R035 error domain equals PXBackupArchiveValidatorErrorDomain.
0814. R035 error code equals 12 (LimitExceeded).
0815. R035 exact field path equals $.artifacts[0].members[0].type.
0816. R035 userInfo keys are exactly description and field path.
0817. R035 description is a nonempty generic NSString.
0818. R035 error values contain no forbidden raw fixture token.
0819. R035 leaves the complete fixture-root snapshot unchanged.
0820. R036 ID and archive ordering are exact.
0821. R036 archive name is exactly R036.tar.gz.
0822. R036 disposition is rejected.
0823. R036 declaration metadata reaches the intended validation branch.
0824. R036 requires a nil result.
0825. R036 requires a nonnil NSError.
0826. R036 error domain equals PXBackupArchiveValidatorErrorDomain.
0827. R036 error code equals 7 (InvalidHeader).
0828. R036 exact field path equals $.artifacts[0].members[1].
0829. R036 userInfo keys are exactly description and field path.
0830. R036 description is a nonempty generic NSString.
0831. R036 error values contain no forbidden raw fixture token.
0832. R036 leaves the complete fixture-root snapshot unchanged.
0833. R037 ID and archive ordering are exact.
0834. R037 archive name is exactly R037.tar.gz.
0835. R037 disposition is rejected.
0836. R037 declaration metadata reaches the intended validation branch.
0837. R037 requires a nil result.
0838. R037 requires a nonnil NSError.
0839. R037 error domain equals PXBackupArchiveValidatorErrorDomain.
0840. R037 error code equals 6 (TruncatedArchive).
0841. R037 exact field path equals $.artifacts[0].members[1].
0842. R037 userInfo keys are exactly description and field path.
0843. R037 description is a nonempty generic NSString.
0844. R037 error values contain no forbidden raw fixture token.
0845. R037 leaves the complete fixture-root snapshot unchanged.
0846. R038 ID and archive ordering are exact.
0847. R038 archive name is exactly R038.tar.gz.
0848. R038 disposition is rejected.
0849. R038 declaration metadata reaches the intended validation branch.
0850. R038 requires a nil result.
0851. R038 requires a nonnil NSError.
0852. R038 error domain equals PXBackupArchiveValidatorErrorDomain.
0853. R038 error code equals 6 (TruncatedArchive).
0854. R038 exact field path equals $.artifacts[0].members[1].
0855. R038 userInfo keys are exactly description and field path.
0856. R038 description is a nonempty generic NSString.
0857. R038 error values contain no forbidden raw fixture token.
0858. R038 leaves the complete fixture-root snapshot unchanged.
0859. R039 ID and archive ordering are exact.
0860. R039 archive name is exactly R039.tar.gz.
0861. R039 disposition is rejected.
0862. R039 declaration metadata reaches the intended validation branch.
0863. R039 requires a nil result.
0864. R039 requires a nonnil NSError.
0865. R039 error domain equals PXBackupArchiveValidatorErrorDomain.
0866. R039 error code equals 6 (TruncatedArchive).
0867. R039 exact field path equals $.artifacts[0].members[1].
0868. R039 userInfo keys are exactly description and field path.
0869. R039 description is a nonempty generic NSString.
0870. R039 error values contain no forbidden raw fixture token.
0871. R039 leaves the complete fixture-root snapshot unchanged.
0872. R040 ID and archive ordering are exact.
0873. R040 archive name is exactly R040.tar.gz.
0874. R040 disposition is rejected.
0875. R040 declaration metadata reaches the intended validation branch.
0876. R040 requires a nil result.
0877. R040 requires a nonnil NSError.
0878. R040 error domain equals PXBackupArchiveValidatorErrorDomain.
0879. R040 error code equals 6 (TruncatedArchive).
0880. R040 exact field path equals $.artifacts[0].members[1].
0881. R040 userInfo keys are exactly description and field path.
0882. R040 description is a nonempty generic NSString.
0883. R040 error values contain no forbidden raw fixture token.
0884. R040 leaves the complete fixture-root snapshot unchanged.
0885. R041 ID and archive ordering are exact.
0886. R041 archive name is exactly R041.tar.gz.
0887. R041 disposition is rejected.
0888. R041 declaration metadata reaches the intended validation branch.
0889. R041 requires a nil result.
0890. R041 requires a nonnil NSError.
0891. R041 error domain equals PXBackupArchiveValidatorErrorDomain.
0892. R041 error code equals 6 (TruncatedArchive).
0893. R041 exact field path equals $.artifacts[0].members[1].
0894. R041 userInfo keys are exactly description and field path.
0895. R041 description is a nonempty generic NSString.
0896. R041 error values contain no forbidden raw fixture token.
0897. R041 leaves the complete fixture-root snapshot unchanged.
0898. R042 ID and archive ordering are exact.
0899. R042 archive name is exactly R042.tar.gz.
0900. R042 disposition is rejected.
0901. R042 declaration metadata reaches the intended validation branch.
0902. R042 requires a nil result.
0903. R042 requires a nonnil NSError.
0904. R042 error domain equals PXBackupArchiveValidatorErrorDomain.
0905. R042 error code equals 7 (InvalidHeader).
0906. R042 exact field path equals $.artifacts[0].members[1].
0907. R042 userInfo keys are exactly description and field path.
0908. R042 description is a nonempty generic NSString.
0909. R042 error values contain no forbidden raw fixture token.
0910. R042 leaves the complete fixture-root snapshot unchanged.
0911. R043 ID and archive ordering are exact.
0912. R043 archive name is exactly R043.tar.gz.
0913. R043 disposition is rejected.
0914. R043 declaration metadata reaches the intended validation branch.
0915. R043 requires a nil result.
0916. R043 requires a nonnil NSError.
0917. R043 error domain equals PXBackupArchiveValidatorErrorDomain.
0918. R043 error code equals 5 (UnsupportedCompression).
0919. R043 exact field path equals $.data.archive.
0920. R043 userInfo keys are exactly description and field path.
0921. R043 description is a nonempty generic NSString.
0922. R043 error values contain no forbidden raw fixture token.
0923. R043 leaves the complete fixture-root snapshot unchanged.
0924. R044 ID and archive ordering are exact.
0925. R044 archive name is exactly R044.tar.gz.
0926. R044 disposition is rejected.
0927. R044 declaration metadata reaches the intended validation branch.
0928. R044 requires a nil result.
0929. R044 requires a nonnil NSError.
0930. R044 error domain equals PXBackupArchiveValidatorErrorDomain.
0931. R044 error code equals 6 (TruncatedArchive).
0932. R044 exact field path equals $.data.archive.
0933. R044 userInfo keys are exactly description and field path.
0934. R044 description is a nonempty generic NSString.
0935. R044 error values contain no forbidden raw fixture token.
0936. R044 leaves the complete fixture-root snapshot unchanged.
0937. R045 ID and archive ordering are exact.
0938. R045 archive name is exactly R045.tar.gz.
0939. R045 disposition is rejected.
0940. R045 declaration metadata reaches the intended validation branch.
0941. R045 requires a nil result.
0942. R045 requires a nonnil NSError.
0943. R045 error domain equals PXBackupArchiveValidatorErrorDomain.
0944. R045 error code equals 5 (UnsupportedCompression).
0945. R045 exact field path equals $.data.archive.
0946. R045 userInfo keys are exactly description and field path.
0947. R045 description is a nonempty generic NSString.
0948. R045 error values contain no forbidden raw fixture token.
0949. R045 leaves the complete fixture-root snapshot unchanged.
0950. R046 ID and archive ordering are exact.
0951. R046 archive name is exactly R046.tar.gz.
0952. R046 disposition is rejected.
0953. R046 declaration metadata reaches the intended validation branch.
0954. R046 requires a nil result.
0955. R046 requires a nonnil NSError.
0956. R046 error domain equals PXBackupArchiveValidatorErrorDomain.
0957. R046 error code equals 5 (UnsupportedCompression).
0958. R046 exact field path equals $.data.archive.
0959. R046 userInfo keys are exactly description and field path.
0960. R046 description is a nonempty generic NSString.
0961. R046 error values contain no forbidden raw fixture token.
0962. R046 leaves the complete fixture-root snapshot unchanged.
0963. R047 ID and archive ordering are exact.
0964. R047 archive name is exactly R047.tar.gz.
0965. R047 disposition is rejected.
0966. R047 declaration metadata reaches the intended validation branch.
0967. R047 requires a nil result.
0968. R047 requires a nonnil NSError.
0969. R047 error domain equals PXBackupArchiveValidatorErrorDomain.
0970. R047 error code equals 11 (InvalidExtendedHeader).
0971. R047 exact field path equals $.artifacts[0].members[0].
0972. R047 userInfo keys are exactly description and field path.
0973. R047 description is a nonempty generic NSString.
0974. R047 error values contain no forbidden raw fixture token.
0975. R047 leaves the complete fixture-root snapshot unchanged.
0976. R048 ID and archive ordering are exact.
0977. R048 archive name is exactly R048.tar.gz.
0978. R048 disposition is rejected.
0979. R048 declaration metadata reaches the intended validation branch.
0980. R048 requires a nil result.
0981. R048 requires a nonnil NSError.
0982. R048 error domain equals PXBackupArchiveValidatorErrorDomain.
0983. R048 error code equals 11 (InvalidExtendedHeader).
0984. R048 exact field path equals $.artifacts[0].members[0].
0985. R048 userInfo keys are exactly description and field path.
0986. R048 description is a nonempty generic NSString.
0987. R048 error values contain no forbidden raw fixture token.
0988. R048 leaves the complete fixture-root snapshot unchanged.
0989. R049 ID and archive ordering are exact.
0990. R049 archive name is exactly R049.tar.gz.
0991. R049 disposition is rejected.
0992. R049 declaration metadata reaches the intended validation branch.
0993. R049 requires a nil result.
0994. R049 requires a nonnil NSError.
0995. R049 error domain equals PXBackupArchiveValidatorErrorDomain.
0996. R049 error code equals 11 (InvalidExtendedHeader).
0997. R049 exact field path equals $.artifacts[0].members[0].
0998. R049 userInfo keys are exactly description and field path.
0999. R049 description is a nonempty generic NSString.
1000. R049 error values contain no forbidden raw fixture token.
1001. R049 leaves the complete fixture-root snapshot unchanged.
1002. R050 ID and archive ordering are exact.
1003. R050 archive name is exactly R050.tar.gz.
1004. R050 disposition is rejected.
1005. R050 declaration metadata reaches the intended validation branch.
1006. R050 requires a nil result.
1007. R050 requires a nonnil NSError.
1008. R050 error domain equals PXBackupArchiveValidatorErrorDomain.
1009. R050 error code equals 11 (InvalidExtendedHeader).
1010. R050 exact field path equals $.artifacts[0].members[0].
1011. R050 userInfo keys are exactly description and field path.
1012. R050 description is a nonempty generic NSString.
1013. R050 error values contain no forbidden raw fixture token.
1014. R050 leaves the complete fixture-root snapshot unchanged.
1015. R051 ID and archive ordering are exact.
1016. R051 archive name is exactly R051.tar.gz.
1017. R051 disposition is rejected.
1018. R051 declaration metadata reaches the intended validation branch.
1019. R051 requires a nil result.
1020. R051 requires a nonnil NSError.
1021. R051 error domain equals PXBackupArchiveValidatorErrorDomain.
1022. R051 error code equals 11 (InvalidExtendedHeader).
1023. R051 exact field path equals $.artifacts[0].members[0].
1024. R051 userInfo keys are exactly description and field path.
1025. R051 description is a nonempty generic NSString.
1026. R051 error values contain no forbidden raw fixture token.
1027. R051 leaves the complete fixture-root snapshot unchanged.
1028. R052 ID and archive ordering are exact.
1029. R052 archive name is exactly R052.tar.gz.
1030. R052 disposition is rejected.
1031. R052 declaration metadata reaches the intended validation branch.
1032. R052 requires a nil result.
1033. R052 requires a nonnil NSError.
1034. R052 error domain equals PXBackupArchiveValidatorErrorDomain.
1035. R052 error code equals 11 (InvalidExtendedHeader).
1036. R052 exact field path equals $.artifacts[0].members[0].
1037. R052 userInfo keys are exactly description and field path.
1038. R052 description is a nonempty generic NSString.
1039. R052 error values contain no forbidden raw fixture token.
1040. R052 leaves the complete fixture-root snapshot unchanged.
1041. R053 ID and archive ordering are exact.
1042. R053 archive name is exactly R053.tar.gz.
1043. R053 disposition is rejected.
1044. R053 declaration metadata reaches the intended validation branch.
1045. R053 requires a nil result.
1046. R053 requires a nonnil NSError.
1047. R053 error domain equals PXBackupArchiveValidatorErrorDomain.
1048. R053 error code equals 11 (InvalidExtendedHeader).
1049. R053 exact field path equals $.artifacts[0].members[0].
1050. R053 userInfo keys are exactly description and field path.
1051. R053 description is a nonempty generic NSString.
1052. R053 error values contain no forbidden raw fixture token.
1053. R053 leaves the complete fixture-root snapshot unchanged.
1054. R054 ID and archive ordering are exact.
1055. R054 archive name is exactly R054.tar.gz.
1056. R054 disposition is rejected.
1057. R054 declaration metadata reaches the intended validation branch.
1058. R054 requires a nil result.
1059. R054 requires a nonnil NSError.
1060. R054 error domain equals PXBackupArchiveValidatorErrorDomain.
1061. R054 error code equals 10 (UnsupportedEntryType).
1062. R054 exact field path equals $.artifacts[0].members[0].
1063. R054 userInfo keys are exactly description and field path.
1064. R054 description is a nonempty generic NSString.
1065. R054 error values contain no forbidden raw fixture token.
1066. R054 leaves the complete fixture-root snapshot unchanged.
1067. R055 ID and archive ordering are exact.
1068. R055 archive name is exactly R055.tar.gz.
1069. R055 disposition is rejected.
1070. R055 declaration metadata reaches the intended validation branch.
1071. R055 requires a nil result.
1072. R055 requires a nonnil NSError.
1073. R055 error domain equals PXBackupArchiveValidatorErrorDomain.
1074. R055 error code equals 11 (InvalidExtendedHeader).
1075. R055 exact field path equals $.artifacts[0].members[0].
1076. R055 userInfo keys are exactly description and field path.
1077. R055 description is a nonempty generic NSString.
1078. R055 error values contain no forbidden raw fixture token.
1079. R055 leaves the complete fixture-root snapshot unchanged.
1080. R056 ID and archive ordering are exact.
1081. R056 archive name is exactly R056.tar.gz.
1082. R056 disposition is rejected.
1083. R056 declaration metadata reaches the intended validation branch.
1084. R056 requires a nil result.
1085. R056 requires a nonnil NSError.
1086. R056 error domain equals PXBackupArchiveValidatorErrorDomain.
1087. R056 error code equals 11 (InvalidExtendedHeader).
1088. R056 exact field path equals $.artifacts[0].members[0].
1089. R056 userInfo keys are exactly description and field path.
1090. R056 description is a nonempty generic NSString.
1091. R056 error values contain no forbidden raw fixture token.
1092. R056 leaves the complete fixture-root snapshot unchanged.
1093. R057 ID and archive ordering are exact.
1094. R057 archive name is exactly R057.tar.gz.
1095. R057 disposition is rejected.
1096. R057 declaration metadata reaches the intended validation branch.
1097. R057 requires a nil result.
1098. R057 requires a nonnil NSError.
1099. R057 error domain equals PXBackupArchiveValidatorErrorDomain.
1100. R057 error code equals 11 (InvalidExtendedHeader).
1101. R057 exact field path equals $.artifacts[0].members[1].
1102. R057 userInfo keys are exactly description and field path.
1103. R057 description is a nonempty generic NSString.
1104. R057 error values contain no forbidden raw fixture token.
1105. R057 leaves the complete fixture-root snapshot unchanged.
1106. R058 ID and archive ordering are exact.
1107. R058 archive name is exactly R058.tar.gz.
1108. R058 disposition is rejected.
1109. R058 declaration metadata reaches the intended validation branch.
1110. R058 requires a nil result.
1111. R058 requires a nonnil NSError.
1112. R058 error domain equals PXBackupArchiveValidatorErrorDomain.
1113. R058 error code equals 11 (InvalidExtendedHeader).
1114. R058 exact field path equals $.artifacts[0].members[0].
1115. R058 userInfo keys are exactly description and field path.
1116. R058 description is a nonempty generic NSString.
1117. R058 error values contain no forbidden raw fixture token.
1118. R058 leaves the complete fixture-root snapshot unchanged.
1119. R059 ID and archive ordering are exact.
1120. R059 archive name is exactly R059.tar.gz.
1121. R059 disposition is rejected.
1122. R059 declaration metadata reaches the intended validation branch.
1123. R059 requires a nil result.
1124. R059 requires a nonnil NSError.
1125. R059 error domain equals PXBackupArchiveValidatorErrorDomain.
1126. R059 error code equals 11 (InvalidExtendedHeader).
1127. R059 exact field path equals $.artifacts[0].members[0].
1128. R059 userInfo keys are exactly description and field path.
1129. R059 description is a nonempty generic NSString.
1130. R059 error values contain no forbidden raw fixture token.
1131. R059 leaves the complete fixture-root snapshot unchanged.
1132. R060 ID and archive ordering are exact.
1133. R060 archive name is exactly R060.tar.gz.
1134. R060 disposition is rejected.
1135. R060 declaration metadata reaches the intended validation branch.
1136. R060 requires a nil result.
1137. R060 requires a nonnil NSError.
1138. R060 error domain equals PXBackupArchiveValidatorErrorDomain.
1139. R060 error code equals 11 (InvalidExtendedHeader).
1140. R060 exact field path equals $.artifacts[0].members[0].
1141. R060 userInfo keys are exactly description and field path.
1142. R060 description is a nonempty generic NSString.
1143. R060 error values contain no forbidden raw fixture token.
1144. R060 leaves the complete fixture-root snapshot unchanged.
1145. R061 ID and archive ordering are exact.
1146. R061 archive name is exactly R061.tar.gz.
1147. R061 disposition is rejected.
1148. R061 declaration metadata reaches the intended validation branch.
1149. R061 requires a nil result.
1150. R061 requires a nonnil NSError.
1151. R061 error domain equals PXBackupArchiveValidatorErrorDomain.
1152. R061 error code equals 11 (InvalidExtendedHeader).
1153. R061 exact field path equals $.artifacts[0].members[1].type.
1154. R061 userInfo keys are exactly description and field path.
1155. R061 description is a nonempty generic NSString.
1156. R061 error values contain no forbidden raw fixture token.
1157. R061 leaves the complete fixture-root snapshot unchanged.
1158. R062 ID and archive ordering are exact.
1159. R062 archive name is exactly R062.tar.gz.
1160. R062 disposition is rejected.
1161. R062 declaration metadata reaches the intended validation branch.
1162. R062 requires a nil result.
1163. R062 requires a nonnil NSError.
1164. R062 error domain equals PXBackupArchiveValidatorErrorDomain.
1165. R062 error code equals 11 (InvalidExtendedHeader).
1166. R062 exact field path equals $.artifacts[0].members[1].
1167. R062 userInfo keys are exactly description and field path.
1168. R062 description is a nonempty generic NSString.
1169. R062 error values contain no forbidden raw fixture token.
1170. R062 leaves the complete fixture-root snapshot unchanged.
1171. R063 ID and archive ordering are exact.
1172. R063 archive name is exactly R063.tar.gz.
1173. R063 disposition is rejected.
1174. R063 declaration metadata reaches the intended validation branch.
1175. R063 requires a nil result.
1176. R063 requires a nonnil NSError.
1177. R063 error domain equals PXBackupArchiveValidatorErrorDomain.
1178. R063 error code equals 12 (LimitExceeded).
1179. R063 exact field path equals $.artifacts[0].members[0].
1180. R063 userInfo keys are exactly description and field path.
1181. R063 description is a nonempty generic NSString.
1182. R063 error values contain no forbidden raw fixture token.
1183. R063 leaves the complete fixture-root snapshot unchanged.
1184. R064 ID and archive ordering are exact.
1185. R064 archive name is exactly R064.tar.gz.
1186. R064 disposition is rejected.
1187. R064 declaration metadata reaches the intended validation branch.
1188. R064 requires a nil result.
1189. R064 requires a nonnil NSError.
1190. R064 error domain equals PXBackupArchiveValidatorErrorDomain.
1191. R064 error code equals 12 (LimitExceeded).
1192. R064 exact field path equals $.artifacts[0].members[16].
1193. R064 userInfo keys are exactly description and field path.
1194. R064 description is a nonempty generic NSString.
1195. R064 error values contain no forbidden raw fixture token.
1196. R064 leaves the complete fixture-root snapshot unchanged.
1197. R065 ID and archive ordering are exact.
1198. R065 archive name is exactly R065.tar.gz.
1199. R065 disposition is rejected.
1200. R065 declaration metadata reaches the intended validation branch.
1201. R065 requires a nil result.
1202. R065 requires a nonnil NSError.
1203. R065 error domain equals PXBackupArchiveValidatorErrorDomain.
1204. R065 error code equals 13 (SizeMismatch).
1205. R065 exact field path equals $.data.archive.
1206. R065 userInfo keys are exactly description and field path.
1207. R065 description is a nonempty generic NSString.
1208. R065 error values contain no forbidden raw fixture token.
1209. R065 leaves the complete fixture-root snapshot unchanged.
1210. R066 ID and archive ordering are exact.
1211. R066 archive name is exactly R066.tar.gz.
1212. R066 disposition is rejected.
1213. R066 declaration metadata reaches the intended validation branch.
1214. R066 requires a nil result.
1215. R066 requires a nonnil NSError.
1216. R066 error domain equals PXBackupArchiveValidatorErrorDomain.
1217. R066 error code equals 14 (DigestMismatch).
1218. R066 exact field path equals $.data.archive.
1219. R066 userInfo keys are exactly description and field path.
1220. R066 description is a nonempty generic NSString.
1221. R066 error values contain no forbidden raw fixture token.
1222. R066 leaves the complete fixture-root snapshot unchanged.

Explicit scenario count: 1222

## Final boundaries

- No TASK-6.4 review was created.
- No validator correction was attempted.
- No transaction fault injection, filesystem race injection, descriptor failure hook, rollback simulation, process-crash simulation, or TASK-6.6 work was started.
- No generated binary corpus is included in Git.
- No push was performed.

GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
