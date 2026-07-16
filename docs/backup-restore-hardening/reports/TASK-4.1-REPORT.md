# TASK-4.1 Report ? Add Structured Keychain Helper Result

## Baseline and scope
- Required baseline and observed pre-edit HEAD: `02770e21bb1b7c7d691a8ac27c3f0fefabad135b`.
- Phase 3 source review status read from `TASK-3.10A-REVIEW.md`: ACCEPTED and COMPLETED.
- Roadmap state read before completion: TASK-4.1 READY; TASK-4.2 through TASK-4.9 LOCKED.
- Authorized implementation scope is exactly four production files plus this report. Coordinator-owned modified/untracked documentation was preserved and excluded from staging.
- No TASK-4.2 or later behavior is implemented.

### Baseline evidence
`git status --short --untracked-files=all` before implementation (reconstructed exactly by filtering only the four authorized current production paths):
```text
 M docs/backup-restore-hardening/DECISIONS.md
 M docs/backup-restore-hardening/README.md
 M docs/backup-restore-hardening/ROADMAP.md
 M docs/backup-restore-hardening/STATUS.md
?? docs/backup-restore-hardening/reviews/TASK-1.10-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-1.11-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-1.12-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.1-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.10-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.11-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.11A-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.12-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.13-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.13A-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.14-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.14A-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.2-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.3-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.4-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.5-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.6-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.6A-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.7-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.8-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.9-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-3.1-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-3.10-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-3.10A-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-3.2-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-3.3-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-3.4-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-3.5-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-3.6-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-3.6A-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-3.7-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-3.8-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-3.8A-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-3.9-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-3.9A-REVIEW.md
?? docs/backup-restore-hardening/tasks/TASK-1.11-remove-unsafe-permission-and-marker-behavior.md
?? docs/backup-restore-hardening/tasks/TASK-1.12-quarantine-ambiguous-legacy-clear-apis.md
?? docs/backup-restore-hardening/tasks/TASK-2.1-add-manifest-schema-validator.md
?? docs/backup-restore-hardening/tasks/TASK-2.10-stage-and-validate-optional-components.md
?? docs/backup-restore-hardening/tasks/TASK-2.11-transactional-main-data-commit-and-rollback.md
?? docs/backup-restore-hardening/tasks/TASK-2.11A-fix-pre-recovery-proof-and-durability.md
?? docs/backup-restore-hardening/tasks/TASK-2.12-transactional-app-group-commit-and-rollback.md
?? docs/backup-restore-hardening/tasks/TASK-2.13-transactional-optional-component-handling.md
?? docs/backup-restore-hardening/tasks/TASK-2.13A-fix-missing-directory-tree-verifier.md
?? docs/backup-restore-hardening/tasks/TASK-2.14-add-structured-restore-result.md
?? docs/backup-restore-hardening/tasks/TASK-2.14A-fix-assertion-elided-result-state.md
?? docs/backup-restore-hardening/tasks/TASK-2.2-enforce-supported-manifest-versions.md
?? docs/backup-restore-hardening/tasks/TASK-2.3-enforce-exact-restore-bundle-identity.md
?? docs/backup-restore-hardening/tasks/TASK-2.4-remove-recorded-destination-fallbacks.md
?? docs/backup-restore-hardening/tasks/TASK-2.5-add-common-artifact-verifier.md
?? docs/backup-restore-hardening/tasks/TASK-2.6-add-archive-entry-safety-validator.md
?? docs/backup-restore-hardening/tasks/TASK-2.6A-fix-archive-validator-compatibility-and-bounds.md
?? docs/backup-restore-hardening/tasks/TASK-2.7-build-immutable-restore-plan.md
?? docs/backup-restore-hardening/tasks/TASK-2.8-stage-and-validate-main-data.md
?? docs/backup-restore-hardening/tasks/TASK-2.9-stage-and-validate-app-groups.md
?? docs/backup-restore-hardening/tasks/TASK-3.1-create-unique-partial-transaction-directory.md
?? docs/backup-restore-hardening/tasks/TASK-3.10-harden-backup-discovery-and-stale-partial-cleanup.md
?? docs/backup-restore-hardening/tasks/TASK-3.10A-fix-top-level-name-classification-and-rollback-errors.md
?? docs/backup-restore-hardening/tasks/TASK-3.2-add-per-bundle-backup-serialization.md
?? docs/backup-restore-hardening/tasks/TASK-3.3-add-common-verified-artifact-writer.md
?? docs/backup-restore-hardening/tasks/TASK-3.4-derive-preferences-inclusion-from-verified-output.md
?? docs/backup-restore-hardening/tasks/TASK-3.5-define-required-and-optional-artifact-policy.md
?? docs/backup-restore-hardening/tasks/TASK-3.6-introduce-manifest-schema-v4.md
?? docs/backup-restore-hardening/tasks/TASK-3.6A-fix-v4-malformed-type-exception-safety.md
?? docs/backup-restore-hardening/tasks/TASK-3.7-write-and-validate-manifest-atomically.md
?? docs/backup-restore-hardening/tasks/TASK-3.8-publish-completed-backup-atomically.md
?? docs/backup-restore-hardening/tasks/TASK-3.8A-enforce-atomic-no-replace-directory-publication.md
?? docs/backup-restore-hardening/tasks/TASK-3.9-centralize-backup-failure-cleanup.md
?? docs/backup-restore-hardening/tasks/TASK-3.9A-make-cleanup-removal-race-safe.md
?? docs/backup-restore-hardening/tasks/TASK-4.1-add-structured-keychain-helper-result.md
```
`git rev-parse HEAD`:
```text
02770e21bb1b7c7d691a8ac27c3f0fefabad135b
```
`git log -8 --oneline`:
```text
02770e2 phase3(task-3.10A): fix stale name classification and rollback errors
5e70a8f phase3(task-3.10): harden backup discovery and stale cleanup
aa01f73 phase3(task-3.9A): make cleanup removal race safe
aa47468 phase3(task-3.9): centralize backup failure cleanup
e55e9d6 phase3(task-3.8A): make directory publication no-replace
494cae0 phase3(task-3.8): publish completed backup atomically
bf9e518 phase3(task-3.7): write and validate manifest atomically
3a7d3f8 phase3(task-3.6A): make manifest v4 type validation exception safe
```
`git diff --check` baseline-owned paths: PASS; no whitespace error output. Existing line-ending warnings from coordinator documentation were non-fatal and those files were not touched.

## Old mutable result inventory
The existing `PXKeychainBackupResult` remains an operation-layer mutable carrier owned by `KeychainBackupHelper`: writable `itemsProcessed`, `itemsSucceeded`, `itemsFailed`, `warnings`, and `errors`, initialized with mutable-lifecycle semantics and populated during Security operations. TASK-4.1 does not change that class or any Keychain operation. The new `PXKeychainHelperResult` is a separate immutable CLI-boundary projection with bounded scalar counts and a privacy-minimized fatal error projection.

## Exact public API, enums, and errors
- Exports: `PXKeychainHelperResultSchemaVersion = 1`, `PXKeychainHelperResultOutputPrefix = @"PXKEYCHAIN_HELPER_RESULT_V1="`, `PXKeychainHelperResultErrorDomain = @"com.hydra.projectx.keychain-helper-result"`, and `PXKeychainHelperResultErrorFieldPathKey = @"fieldPath"`.
- Operation enum: Unknown=0, Backup=1, Restore=2, Wipe=3, List=4; exact strings `unknown`, `backup`, `restore`, `wipe`, `list`.
- Completion enum: Failed=1, Completed=2, Partial=3; exact strings `failed`, `completed`, `partial`.
- Error codes are exactly InvalidInput, InvalidOperation, InvalidCompletion, InvalidCounts, InvalidFatalError, LimitExceeded, SerializationFailed, and InternalInvariantFailed, numbered 1 through 8.
- `PXKeychainHelperResult` is `objc_subclassing_restricted`, conforms to `NSCopying`, exposes exactly fourteen readonly properties, has one public factory, and marks `init`/`new` unavailable.

## Immutable invariants
- All six counts are bounded to 1,000,000. The relation `succeeded + failed + skipped <= attempted` is proved by ordered subtraction, so no addition can overflow.
- Unknown operation is valid only with Failed completion. Failed requires an `NSError`; Completed and Partial forbid it.
- Completed requires failed/skipped/warning/error all zero. Partial requires at least one of those four issue counts to be nonzero.
- Fatal domain is copied only after strict, lossless UTF-8 round trip; it must be nonempty, NUL-free, control-free, and at most 255 UTF-8 bytes.
- The implementation retains only scalar state, copied fatal domain/code, immutable decoded property-list representation, and final line. `copyWithZone:` returns self. Equality/hash derive from the entire retained ten-key snapshot.

## Exact ten-key representation
The root dictionary is closed and contains exactly: `schemaVersion`, `operation`, `completion`, `attemptedCount`, `succeededCount`, `failedCount`, `skippedCount`, `warningCount`, `errorCount`, and `fatalError`. The nested `fatalError` dictionary contains exactly `present`, `domain`, and `code`. No-fatal representation is exactly `present=false`, `domain=""`, `code=0`. Exact key sets, scalar types, strings, counts, and retained property values are checked before and after serialization.

## Privacy exclusions
The result never retains or serializes the fatal error object, localized description, userInfo, underlying error, path, bundle identifier, access groups, item identity, secret, or item metadata. Construction errors use fixed bounded descriptions and `fieldPath`; those errors are returned to the caller and are not part of the result envelope.

## Binary-plist and base64 framing
- The immutable snapshot is serialized at the single serializer site with `NSPropertyListBinaryFormat_v1_0`; maximum binary size is 16 KiB.
- Base64 uses options `0`, has no line breaks, and is limited to 24 KiB. Decode must reproduce the exact binary bytes.
- Immutable property-list read-back must report binary v1 format, deep-equal the source snapshot, have exact closed key sets/types, and match every retained property.
- `machineReadableLine` is exactly `PXKEYCHAIN_HELPER_RESULT_V1=<base64>`, prefix at byte zero exactly once, maximum 25 KiB, with no CR/LF suffix.

## Completion derivation and count mapping
- Backup/restore/wipe nil helper result -> Failed with the helper NSError or a bounded synthetic `PXKeychainBackupErrorDomain` error.
- Existing result with any `itemsFailed`, warnings, or errors -> Partial. Otherwise -> Completed.
- Counts map exactly: attempted=`itemsProcessed`, succeeded=`itemsSucceeded`, failed=`itemsFailed`, skipped=0, warnings=`warnings.count`, errors=`errors.count`.
- List is Completed with attempted/succeeded=`items.count`; all other counts are zero.
- Missing/unknown arguments use Unknown or the exact selected operation, Failed completion, and bounded synthetic `PXKeychainBackupErrorDomain` errors.

## Terminal-path emission inventory
| Terminal path | Envelope | Legacy exit |
|---|---|---:|
| `--help` | no result line; existing usage | 0 |
| `-h` | no result line; existing usage | 0 |
| `missing --action` | unknown/failed synthetic InvalidArguments; one result line | 1 |
| `unknown --action value` | unknown/failed synthetic InvalidArguments; one result line | 1 |
| `backup missing --file` | backup/failed synthetic InvalidArguments; one result line | 1 |
| `backup missing --groups` | backup/failed synthetic NoAccessGroups; one result line | 1 |
| `backup helper nil with NSError` | backup/failed domain+code only; one result line | 2 |
| `backup helper nil without NSError` | backup/failed synthetic Unknown; one result line | 2 |
| `backup result clean` | backup/completed; mapped counts; one result line | 0 |
| `backup result itemsFailed>0` | backup/partial; mapped counts; one result line | 0 |
| `backup result warning` | backup/partial; mapped counts; one result line | 0 |
| `backup result error` | backup/partial; mapped counts; one result line | 0 |
| `restore missing --file` | restore/failed synthetic InvalidArguments; one result line | 1 |
| `restore helper nil with NSError` | restore/failed domain+code only; one result line | 2 |
| `restore helper nil without NSError` | restore/failed synthetic Unknown; one result line | 2 |
| `restore result clean` | restore/completed; mapped counts; one result line | 0 |
| `restore result itemsFailed>0` | restore/partial; mapped counts; one result line | 0 |
| `restore result warning` | restore/partial; mapped counts; one result line | 0 |
| `restore result error` | restore/partial; mapped counts; one result line | 0 |
| `wipe missing --groups` | wipe/failed synthetic NoAccessGroups; one result line | 1 |
| `wipe helper nil` | legacy wipe summary then wipe/failed result line | 2 |
| `wipe result failed items` | legacy wipe summary/warnings then wipe/partial result line | 2 |
| `wipe result warnings` | legacy wipe summary/warnings then wipe/partial result line | 2 |
| `wipe result errors only` | wipe/partial result line while legacy exit remains 0 | unchanged |
| `wipe clean result` | legacy wipe summary/success then wipe/completed result line | 0 |
| `list missing --groups` | list/failed synthetic NoAccessGroups; one result line | 1 |
| `list zero items` | list/completed attempted=0 succeeded=0; one result line | 0 |
| `list N items` | list/completed attempted=N succeeded=N; other counts zero | 0 |
| `unexpected result construction failure` | emit exact PXKEYCHAIN_HELPER_RESULT_V1=INVALID plus LF; preserve selected exit | unchanged |
| `verbose backup` | existing INFO/OK/WARN order retained; structured line appended last | unchanged |
| `verbose restore` | existing INFO/OK/WARN/ERR order retained; structured line appended last | unchanged |
| `verbose list` | existing DIAG/item order retained; structured line appended last | unchanged |
The CLI imports `PXKeychainHelperResult.h` exactly once. All non-help invocations reach exactly one `PXEmitStructuredResult` call before return. The emitter has one result-line `fprintf` site, appends one newline, calls `fflush(stdout)` once, never writes payload to stderr, and never logs payload. Unexpected construction failure emits exactly `PXKEYCHAIN_HELPER_RESULT_V1=INVALID`.

## Exit-code preservation
Completion never selects process exit. Help remains 0; invalid/missing arguments remain 1; backup/restore/wipe nil results remain 2; wipe failures or warnings remain 2; backup/restore result objects remain 0; list success remains 0. Wipe errors-only remains legacy exit 0 even though the new completion is Partial. TASK-4.2 owns any redesign.

## Script passthrough and zero manager/bridge integration
- `scripts/keychain_backup.sh` is byte-identical. It receives the helper stdout/stderr exactly as before; TASK-4.1 adds no shell parsing, filtering, or exit reinterpretation.
- `AppDataBackupManager.h/.m` are byte-identical and contain zero structured-envelope parsing integration.
- `WeaponXKeychainBridge/Tweak.m` and its plist are byte-identical and contain zero structured-envelope parsing integration.

## Makefile exact diff
Only `KeychainHelper/PXKeychainHelperResult.m` is appended once to `backup_helper_FILES`. Tool name, install path, frameworks, codesign flags, script installation, bridge target, and compiler/linker flags are unchanged.
```diff
-backup_helper_FILES = KeychainHelper/backup_helper.m KeychainHelper/KeychainBackupHelper.m
+backup_helper_FILES = KeychainHelper/backup_helper.m KeychainHelper/KeychainBackupHelper.m KeychainHelper/PXKeychainHelperResult.m
```

## Later-task boundaries
Not implemented: TASK-4.2 reliable exit codes; TASK-4.3 broad pre-delete removal; TASK-4.4 exact identity; TASK-4.5 per-item upsert; TASK-4.6 secure temporary workspace/path validation; TASK-4.7 requested/effective group reporting; TASK-4.8 manager/bridge parsing; TASK-4.9 backup protection policy; UI and later-phase work.

## Static gates
| Gate | Observed | Required | Result |
|---|---:|---:|---:|
| Public exports | 4 | 4 | PASS |
| Operation enum values | 5 | 5 | PASS |
| Completion enum values | 3 | 3 | PASS |
| Error codes | 8 | 8 | PASS |
| Public readonly properties | 14 | 14 | PASS |
| Public mutation properties | 0 | 0 | PASS |
| Public factory declarations | 1 | 1 | PASS |
| Factory implementation sites | 1 | 1 | PASS |
| CLI factory call sites | 1 | 1 | PASS |
| CLI emitter definitions | 1 | 1 | PASS |
| Result-line fprintf sites | 1 | 1 | PASS |
| fflush(stdout) sites | 1 | 1 | PASS |
| INVALID literal sites | 1 | 1 | PASS |
| Binary serializer sites | 1 | 1 | PASS |
| Base64 encoder sites | 1 | 1 | PASS |
| Makefile source entries | 1 | 1 | PASS |
| NSMutable references in result implementation | 0 | 0 | PASS |
| dispatch_once references in result implementation | 0 | 0 | PASS |
| localizedDescription references in result implementation | 0 | 0 | PASS |
| NSUnderlyingErrorKey references in result implementation | 0 | 0 | PASS |
| Python invariant/framing model assertions | 500168 | >= 1 | PASS |
| Protected production files checked | 71 | >= 1 | PASS |
| Protected mismatches | 0 | 0 | PASS |
| `git diff --check` authorized source | 0 errors | 0 | PASS |

## Build/toolchain status and device risks
- Python invariant/framing model: PASS, 500,168 assertions, including exhaustive small-state enum/count combinations, 50,000 deterministic random count cases, UTF-8 domain boundaries, exact ten/three-key snapshots, binary plist, base64, and framing limits.
- Objective-C compiler frontend: NOT RUN; `clang` is unavailable on this Windows host.
- Theos build/link: NOT RUN; `make` is unavailable and `THEOS` is unset.
- Apple SDK tooling: NOT RUN; `xcrun` is unavailable.
- Device validation still required for Foundation binary-plist behavior across supported iOS versions, helper stdout ordering through the wrapper, target linker availability of declarations/macros, and runtime behavior when helper counts exceed fixed envelope bounds. GitHub Actions and device tests are authoritative for these risks.

## Authorized source before/after
| File | Before SHA-256 | Before bytes | After SHA-256 | After bytes |
|---|---|---:|---|---:|
| `KeychainHelper/PXKeychainHelperResult.h` | ABSENT | 0 | `96c326226fbb22e7b69dc68f4088aa5e6c171d391ad0bca8d321318f041f9d14` | 3191 |
| `KeychainHelper/PXKeychainHelperResult.m` | ABSENT | 0 | `2ff85dd7bc0e3af97b0fdf2ccd00072d6ba2d324ef70e4c4e26b739d745d9035` | 27477 |
| `KeychainHelper/backup_helper.m` | `9f4e2c1cd0d7ebb7afef93d537e759858d60d2ae2ddd89b7b535ec611d437b83` | 14129 | `0f68c2eef016ea098d7f83a10e2016693caefa994fab58e5a5801b02c8ebaecf` | 24800 |
| `Makefile` | `717465ec5894548e894412aa7f4205f4b8d5ac7e9d13339327477dd686d6c9a9` | 9146 | `9ed7ed6b376c96b8a3df8d9e169670476feabee186a177f9fe09118265a6d8c0` | 9186 |

## Explicit numbered scenario matrix
Explicit scenarios: 312.

| # | Category | Input/state | Expected result |
|---:|---|---|---|
| 1 | public export | schema version export | exact exported value is 1 |
| 2 | public export | output prefix export | exact exported value is PXKEYCHAIN_HELPER_RESULT_V1= |
| 3 | public export | error domain export | exact exported value is com.hydra.projectx.keychain-helper-result |
| 4 | public export | field-path export | exact exported value is fieldPath |
| 5 | operation enum | Unknown = 0 | serializes exactly as unknown |
| 6 | operation enum | Backup = 1 | serializes exactly as backup |
| 7 | operation enum | Restore = 2 | serializes exactly as restore |
| 8 | operation enum | Wipe = 3 | serializes exactly as wipe |
| 9 | operation enum | List = 4 | serializes exactly as list |
| 10 | completion enum | Failed = 1 | serializes exactly as failed |
| 11 | completion enum | Completed = 2 | serializes exactly as completed |
| 12 | completion enum | Partial = 3 | serializes exactly as partial |
| 13 | error code | InvalidInput = 1 | public error code exists exactly once |
| 14 | error code | InvalidOperation = 2 | public error code exists exactly once |
| 15 | error code | InvalidCompletion = 3 | public error code exists exactly once |
| 16 | error code | InvalidCounts = 4 | public error code exists exactly once |
| 17 | error code | InvalidFatalError = 5 | public error code exists exactly once |
| 18 | error code | LimitExceeded = 6 | public error code exists exactly once |
| 19 | error code | SerializationFailed = 7 | public error code exists exactly once |
| 20 | error code | InternalInvariantFailed = 8 | public error code exists exactly once |
| 21 | immutable API | schemaVersion | readonly property; no public setter or mutation method |
| 22 | immutable API | operation | readonly property; no public setter or mutation method |
| 23 | immutable API | completion | readonly property; no public setter or mutation method |
| 24 | immutable API | attemptedCount | readonly property; no public setter or mutation method |
| 25 | immutable API | succeededCount | readonly property; no public setter or mutation method |
| 26 | immutable API | failedCount | readonly property; no public setter or mutation method |
| 27 | immutable API | skippedCount | readonly property; no public setter or mutation method |
| 28 | immutable API | warningCount | readonly property; no public setter or mutation method |
| 29 | immutable API | errorCount | readonly property; no public setter or mutation method |
| 30 | immutable API | fatalErrorPresent | readonly property; no public setter or mutation method |
| 31 | immutable API | fatalErrorDomain | readonly property; no public setter or mutation method |
| 32 | immutable API | fatalErrorCode | readonly property; no public setter or mutation method |
| 33 | immutable API | propertyListRepresentation | readonly property; no public setter or mutation method |
| 34 | immutable API | machineReadableLine | readonly property; no public setter or mutation method |
| 35 | immutable API | init | unavailable |
| 36 | immutable API | new | unavailable |
| 37 | immutable API | copyWithZone: | returns self |
| 38 | immutable API | subclass attempt | blocked by objc_subclassing_restricted |
| 39 | immutable API | two equal snapshots | isEqual/hash use the full retained property-list state |
| 40 | immutable API | one retained field differs | objects compare unequal and hash follows full snapshot |
| 41 | operation validation | operation raw value -9223372036854775808 | reject InvalidOperation |
| 42 | operation validation | operation raw value -100 | reject InvalidOperation |
| 43 | operation validation | operation raw value -2 | reject InvalidOperation |
| 44 | operation validation | operation raw value -1 | reject InvalidOperation |
| 45 | operation validation | operation raw value 5 | reject InvalidOperation |
| 46 | operation validation | operation raw value 6 | reject InvalidOperation |
| 47 | operation validation | operation raw value 100 | reject InvalidOperation |
| 48 | operation validation | operation raw value 9223372036854775807 | reject InvalidOperation |
| 49 | completion validation | completion raw value -9223372036854775808 | reject InvalidCompletion |
| 50 | completion validation | completion raw value -100 | reject InvalidCompletion |
| 51 | completion validation | completion raw value -1 | reject InvalidCompletion |
| 52 | completion validation | completion raw value 0 | reject InvalidCompletion |
| 53 | completion validation | completion raw value 4 | reject InvalidCompletion |
| 54 | completion validation | completion raw value 5 | reject InvalidCompletion |
| 55 | completion validation | completion raw value 100 | reject InvalidCompletion |
| 56 | completion validation | completion raw value 9223372036854775807 | reject InvalidCompletion |
| 57 | count bound | attemptedCount = 0 | accepted subject to cross-field invariants |
| 58 | count bound | attemptedCount = 1 | accepted subject to cross-field invariants |
| 59 | count bound | attemptedCount = 999999 | accepted subject to cross-field invariants |
| 60 | count bound | attemptedCount = 1000000 | accepted subject to cross-field invariants |
| 61 | count bound | attemptedCount = 1000001 | reject LimitExceeded without arithmetic overflow |
| 62 | count bound | succeededCount = 0 | accepted subject to cross-field invariants |
| 63 | count bound | succeededCount = 1 | accepted subject to cross-field invariants |
| 64 | count bound | succeededCount = 999999 | accepted subject to cross-field invariants |
| 65 | count bound | succeededCount = 1000000 | accepted subject to cross-field invariants |
| 66 | count bound | succeededCount = 1000001 | reject LimitExceeded without arithmetic overflow |
| 67 | count bound | failedCount = 0 | accepted subject to cross-field invariants |
| 68 | count bound | failedCount = 1 | accepted subject to cross-field invariants |
| 69 | count bound | failedCount = 999999 | accepted subject to cross-field invariants |
| 70 | count bound | failedCount = 1000000 | accepted subject to cross-field invariants |
| 71 | count bound | failedCount = 1000001 | reject LimitExceeded without arithmetic overflow |
| 72 | count bound | skippedCount = 0 | accepted subject to cross-field invariants |
| 73 | count bound | skippedCount = 1 | accepted subject to cross-field invariants |
| 74 | count bound | skippedCount = 999999 | accepted subject to cross-field invariants |
| 75 | count bound | skippedCount = 1000000 | accepted subject to cross-field invariants |
| 76 | count bound | skippedCount = 1000001 | reject LimitExceeded without arithmetic overflow |
| 77 | count bound | warningCount = 0 | accepted subject to cross-field invariants |
| 78 | count bound | warningCount = 1 | accepted subject to cross-field invariants |
| 79 | count bound | warningCount = 999999 | accepted subject to cross-field invariants |
| 80 | count bound | warningCount = 1000000 | accepted subject to cross-field invariants |
| 81 | count bound | warningCount = 1000001 | reject LimitExceeded without arithmetic overflow |
| 82 | count bound | errorCount = 0 | accepted subject to cross-field invariants |
| 83 | count bound | errorCount = 1 | accepted subject to cross-field invariants |
| 84 | count bound | errorCount = 999999 | accepted subject to cross-field invariants |
| 85 | count bound | errorCount = 1000000 | accepted subject to cross-field invariants |
| 86 | count bound | errorCount = 1000001 | reject LimitExceeded without arithmetic overflow |
| 87 | count relation | attempted=0, succeeded=0, failed=0, skipped=0 | accept |
| 88 | count relation | attempted=1, succeeded=1, failed=0, skipped=0 | accept |
| 89 | count relation | attempted=1, succeeded=0, failed=1, skipped=0 | accept |
| 90 | count relation | attempted=1, succeeded=0, failed=0, skipped=1 | accept |
| 91 | count relation | attempted=3, succeeded=1, failed=1, skipped=1 | accept |
| 92 | count relation | attempted=3, succeeded=2, failed=1, skipped=0 | accept |
| 93 | count relation | attempted=3, succeeded=3, failed=0, skipped=0 | accept |
| 94 | count relation | attempted=2, succeeded=2, failed=1, skipped=0 | reject InvalidCounts using subtraction-based overflow-safe proof |
| 95 | count relation | attempted=2, succeeded=1, failed=2, skipped=0 | reject InvalidCounts using subtraction-based overflow-safe proof |
| 96 | count relation | attempted=2, succeeded=1, failed=1, skipped=1 | reject InvalidCounts using subtraction-based overflow-safe proof |
| 97 | count relation | attempted=1000000, succeeded=1000000, failed=0, skipped=0 | accept |
| 98 | count relation | attempted=1000000, succeeded=999999, failed=1, skipped=0 | accept |
| 99 | count relation | attempted=1000000, succeeded=999999, failed=0, skipped=1 | accept |
| 100 | failed invariant | unknown/failed with NSError | accept when counts/domain are valid |
| 101 | failed invariant | unknown/failed without NSError | reject InvalidFatalError |
| 102 | failed invariant | backup/failed with NSError | accept when counts/domain are valid |
| 103 | failed invariant | backup/failed without NSError | reject InvalidFatalError |
| 104 | failed invariant | restore/failed with NSError | accept when counts/domain are valid |
| 105 | failed invariant | restore/failed without NSError | reject InvalidFatalError |
| 106 | failed invariant | wipe/failed with NSError | accept when counts/domain are valid |
| 107 | failed invariant | wipe/failed without NSError | reject InvalidFatalError |
| 108 | failed invariant | list/failed with NSError | accept when counts/domain are valid |
| 109 | failed invariant | list/failed without NSError | reject InvalidFatalError |
| 110 | completed invariant | backup/completed with no failed/skipped/warning/error | accept |
| 111 | completed invariant | backup/completed with failed=1 | reject InvalidCompletion |
| 112 | completed invariant | backup/completed with skipped=1 | reject InvalidCompletion |
| 113 | completed invariant | backup/completed with warning=1 | reject InvalidCompletion |
| 114 | completed invariant | backup/completed with error=1 | reject InvalidCompletion |
| 115 | partial invariant | backup/partial with failed=1 | accept |
| 116 | partial invariant | backup/partial with skipped=1 | accept |
| 117 | partial invariant | backup/partial with warning=1 | accept |
| 118 | partial invariant | backup/partial with error=1 | accept |
| 119 | partial invariant | backup/partial with all issue counts zero | reject InvalidCompletion |
| 120 | fatal invariant | backup/completed with NSError | reject InvalidFatalError |
| 121 | fatal invariant | backup/partial with NSError | reject InvalidFatalError |
| 122 | completed invariant | restore/completed with no failed/skipped/warning/error | accept |
| 123 | completed invariant | restore/completed with failed=1 | reject InvalidCompletion |
| 124 | completed invariant | restore/completed with skipped=1 | reject InvalidCompletion |
| 125 | completed invariant | restore/completed with warning=1 | reject InvalidCompletion |
| 126 | completed invariant | restore/completed with error=1 | reject InvalidCompletion |
| 127 | partial invariant | restore/partial with failed=1 | accept |
| 128 | partial invariant | restore/partial with skipped=1 | accept |
| 129 | partial invariant | restore/partial with warning=1 | accept |
| 130 | partial invariant | restore/partial with error=1 | accept |
| 131 | partial invariant | restore/partial with all issue counts zero | reject InvalidCompletion |
| 132 | fatal invariant | restore/completed with NSError | reject InvalidFatalError |
| 133 | fatal invariant | restore/partial with NSError | reject InvalidFatalError |
| 134 | completed invariant | wipe/completed with no failed/skipped/warning/error | accept |
| 135 | completed invariant | wipe/completed with failed=1 | reject InvalidCompletion |
| 136 | completed invariant | wipe/completed with skipped=1 | reject InvalidCompletion |
| 137 | completed invariant | wipe/completed with warning=1 | reject InvalidCompletion |
| 138 | completed invariant | wipe/completed with error=1 | reject InvalidCompletion |
| 139 | partial invariant | wipe/partial with failed=1 | accept |
| 140 | partial invariant | wipe/partial with skipped=1 | accept |
| 141 | partial invariant | wipe/partial with warning=1 | accept |
| 142 | partial invariant | wipe/partial with error=1 | accept |
| 143 | partial invariant | wipe/partial with all issue counts zero | reject InvalidCompletion |
| 144 | fatal invariant | wipe/completed with NSError | reject InvalidFatalError |
| 145 | fatal invariant | wipe/partial with NSError | reject InvalidFatalError |
| 146 | completed invariant | list/completed with no failed/skipped/warning/error | accept |
| 147 | completed invariant | list/completed with failed=1 | reject InvalidCompletion |
| 148 | completed invariant | list/completed with skipped=1 | reject InvalidCompletion |
| 149 | completed invariant | list/completed with warning=1 | reject InvalidCompletion |
| 150 | completed invariant | list/completed with error=1 | reject InvalidCompletion |
| 151 | partial invariant | list/partial with failed=1 | accept |
| 152 | partial invariant | list/partial with skipped=1 | accept |
| 153 | partial invariant | list/partial with warning=1 | accept |
| 154 | partial invariant | list/partial with error=1 | accept |
| 155 | partial invariant | list/partial with all issue counts zero | reject InvalidCompletion |
| 156 | fatal invariant | list/completed with NSError | reject InvalidFatalError |
| 157 | fatal invariant | list/partial with NSError | reject InvalidFatalError |
| 158 | unknown invariant | unknown/completed | reject InvalidOperation |
| 159 | unknown invariant | unknown/partial | reject InvalidOperation |
| 160 | unknown invariant | unknown/failed with bounded NSError | accept |
| 161 | fatal domain | empty | reject InvalidFatalError or LimitExceeded before serialization |
| 162 | fatal domain | one ASCII byte | accept losslessly |
| 163 | fatal domain | 255 ASCII bytes | accept losslessly |
| 164 | fatal domain | 256 ASCII bytes | reject InvalidFatalError or LimitExceeded before serialization |
| 165 | fatal domain | 127 two-byte characters | accept losslessly |
| 166 | fatal domain | 128 two-byte characters | reject InvalidFatalError or LimitExceeded before serialization |
| 167 | fatal domain | Greek UTF-8 | accept losslessly |
| 168 | fatal domain | newline | reject InvalidFatalError or LimitExceeded before serialization |
| 169 | fatal domain | carriage return | reject InvalidFatalError or LimitExceeded before serialization |
| 170 | fatal domain | tab | reject InvalidFatalError or LimitExceeded before serialization |
| 171 | fatal domain | NUL | reject InvalidFatalError or LimitExceeded before serialization |
| 172 | fatal domain | DEL | reject InvalidFatalError or LimitExceeded before serialization |
| 173 | fatal domain | C1 control | reject InvalidFatalError or LimitExceeded before serialization |
| 174 | fatal domain | bounded production domain | accept losslessly |
| 175 | privacy exclusion | localizedDescription | not retained or serialized in PXKeychainHelperResult |
| 176 | privacy exclusion | fatal userInfo | not retained or serialized in PXKeychainHelperResult |
| 177 | privacy exclusion | NSUnderlyingErrorKey | not retained or serialized in PXKeychainHelperResult |
| 178 | privacy exclusion | underlying error object | not retained or serialized in PXKeychainHelperResult |
| 179 | privacy exclusion | path | not retained or serialized in PXKeychainHelperResult |
| 180 | privacy exclusion | bundle identifier | not retained or serialized in PXKeychainHelperResult |
| 181 | privacy exclusion | access group | not retained or serialized in PXKeychainHelperResult |
| 182 | privacy exclusion | item identity | not retained or serialized in PXKeychainHelperResult |
| 183 | privacy exclusion | secret data | not retained or serialized in PXKeychainHelperResult |
| 184 | privacy exclusion | item metadata | not retained or serialized in PXKeychainHelperResult |
| 185 | fatal projection | fatal NSError has domain/code plus sensitive userInfo | retain only copied domain and integer code |
| 186 | no-fatal projection | completed/partial result | fatalError={present:false, domain:"", code:0} |
| 187 | exact root representation | schemaVersion | present exactly once in the ten-key root |
| 188 | exact root representation | operation | present exactly once in the ten-key root |
| 189 | exact root representation | completion | present exactly once in the ten-key root |
| 190 | exact root representation | attemptedCount | present exactly once in the ten-key root |
| 191 | exact root representation | succeededCount | present exactly once in the ten-key root |
| 192 | exact root representation | failedCount | present exactly once in the ten-key root |
| 193 | exact root representation | skippedCount | present exactly once in the ten-key root |
| 194 | exact root representation | warningCount | present exactly once in the ten-key root |
| 195 | exact root representation | errorCount | present exactly once in the ten-key root |
| 196 | exact root representation | fatalError | present exactly once in the ten-key root |
| 197 | exact fatal representation | present | present exactly once in the three-key fatalError dictionary |
| 198 | exact fatal representation | domain | present exactly once in the three-key fatalError dictionary |
| 199 | exact fatal representation | code | present exactly once in the three-key fatalError dictionary |
| 200 | closed schema | extra root key localizedDescription | never emitted |
| 201 | closed schema | extra root key userInfo | never emitted |
| 202 | closed schema | extra root key path | never emitted |
| 203 | closed schema | extra root key bundleID | never emitted |
| 204 | closed schema | extra root key accessGroups | never emitted |
| 205 | closed schema | extra root key items | never emitted |
| 206 | closed schema | extra root key secret | never emitted |
| 207 | framing | NSPropertyListBinaryFormat_v1_0 | enforced before result construction succeeds |
| 208 | framing | NSPropertyListImmutable read-back | enforced before result construction succeeds |
| 209 | framing | base64 options 0 | enforced before result construction succeeds |
| 210 | framing | prefix at byte zero | enforced before result construction succeeds |
| 211 | framing | no base64 line breaks | enforced before result construction succeeds |
| 212 | framing | no trailing LF | enforced before result construction succeeds |
| 213 | framing | no trailing CR | enforced before result construction succeeds |
| 214 | framing | single prefix occurrence | enforced before result construction succeeds |
| 215 | framing | decoded graph deep equality | enforced before result construction succeeds |
| 216 | framing | decoded values match retained properties | enforced before result construction succeeds |
| 217 | framing limit | binary plist exactly 16384 bytes | accepted when all other invariants hold |
| 218 | framing limit | binary plist greater than 16384 bytes | reject LimitExceeded; CLI fallback is exact INVALID line |
| 219 | framing limit | base64 exactly 24576 bytes | accepted when all other invariants hold |
| 220 | framing limit | base64 greater than 24576 bytes | reject LimitExceeded; CLI fallback is exact INVALID line |
| 221 | framing limit | complete output line exactly 25600 bytes | accepted when all other invariants hold |
| 222 | framing limit | complete output line greater than 25600 bytes | reject LimitExceeded; CLI fallback is exact INVALID line |
| 223 | serialization failure | NSPropertyListSerialization returns nil/error | reject SerializationFailed |
| 224 | round trip failure | base64 decode differs from serialized bytes | reject InternalInvariantFailed |
| 225 | read-back failure | decoded plist format or graph differs | reject InternalInvariantFailed |
| 226 | CLI terminal path | --help | no result line; existing usage; exit 0 |
| 227 | CLI terminal path | -h | no result line; existing usage; exit 0 |
| 228 | CLI terminal path | missing --action | unknown/failed synthetic InvalidArguments; one result line; exit 1 |
| 229 | CLI terminal path | unknown --action value | unknown/failed synthetic InvalidArguments; one result line; exit 1 |
| 230 | CLI terminal path | backup missing --file | backup/failed synthetic InvalidArguments; one result line; exit 1 |
| 231 | CLI terminal path | backup missing --groups | backup/failed synthetic NoAccessGroups; one result line; exit 1 |
| 232 | CLI terminal path | backup helper nil with NSError | backup/failed domain+code only; one result line; exit 2 |
| 233 | CLI terminal path | backup helper nil without NSError | backup/failed synthetic Unknown; one result line; exit 2 |
| 234 | CLI terminal path | backup result clean | backup/completed; mapped counts; one result line; exit 0 |
| 235 | CLI terminal path | backup result itemsFailed>0 | backup/partial; mapped counts; one result line; exit 0 |
| 236 | CLI terminal path | backup result warning | backup/partial; mapped counts; one result line; exit 0 |
| 237 | CLI terminal path | backup result error | backup/partial; mapped counts; one result line; exit 0 |
| 238 | CLI terminal path | restore missing --file | restore/failed synthetic InvalidArguments; one result line; exit 1 |
| 239 | CLI terminal path | restore helper nil with NSError | restore/failed domain+code only; one result line; exit 2 |
| 240 | CLI terminal path | restore helper nil without NSError | restore/failed synthetic Unknown; one result line; exit 2 |
| 241 | CLI terminal path | restore result clean | restore/completed; mapped counts; one result line; exit 0 |
| 242 | CLI terminal path | restore result itemsFailed>0 | restore/partial; mapped counts; one result line; exit 0 |
| 243 | CLI terminal path | restore result warning | restore/partial; mapped counts; one result line; exit 0 |
| 244 | CLI terminal path | restore result error | restore/partial; mapped counts; one result line; exit 0 |
| 245 | CLI terminal path | wipe missing --groups | wipe/failed synthetic NoAccessGroups; one result line; exit 1 |
| 246 | CLI terminal path | wipe helper nil | legacy wipe summary then wipe/failed result line; exit 2 |
| 247 | CLI terminal path | wipe result failed items | legacy wipe summary/warnings then wipe/partial result line; exit 2 |
| 248 | CLI terminal path | wipe result warnings | legacy wipe summary/warnings then wipe/partial result line; exit 2 |
| 249 | CLI terminal path | wipe result errors only | wipe/partial result line while legacy exit remains 0 |
| 250 | CLI terminal path | wipe clean result | legacy wipe summary/success then wipe/completed result line; exit 0 |
| 251 | CLI terminal path | list missing --groups | list/failed synthetic NoAccessGroups; one result line; exit 1 |
| 252 | CLI terminal path | list zero items | list/completed attempted=0 succeeded=0; one result line; exit 0 |
| 253 | CLI terminal path | list N items | list/completed attempted=N succeeded=N; other counts zero; exit 0 |
| 254 | CLI terminal path | unexpected result construction failure | emit exact PXKEYCHAIN_HELPER_RESULT_V1=INVALID plus LF; preserve selected exit |
| 255 | CLI terminal path | verbose backup | existing INFO/OK/WARN order retained; structured line appended last |
| 256 | CLI terminal path | verbose restore | existing INFO/OK/WARN/ERR order retained; structured line appended last |
| 257 | CLI terminal path | verbose list | existing DIAG/item order retained; structured line appended last |
| 258 | CLI count mapping | attempted | derived exactly from itemsProcessed |
| 259 | CLI count mapping | succeeded | derived exactly from itemsSucceeded |
| 260 | CLI count mapping | failed | derived exactly from itemsFailed |
| 261 | CLI count mapping | skipped | derived exactly from literal 0 |
| 262 | CLI count mapping | warning | derived exactly from warnings.count |
| 263 | CLI count mapping | error | derived exactly from errors.count |
| 264 | CLI emission | emitter implementation | one fprintf result-line site, one appended newline, one fflush(stdout) |
| 265 | CLI emission | stderr | never receives structured payload |
| 266 | CLI emission | logging | structured payload is never passed to existing log helpers |
| 267 | CLI emission | machineReadableLine property | contains no trailing newline |
| 268 | protected production | KeychainHelper/KeychainBackupHelper.h | before/after SHA-256 and byte size match; protected diff empty |
| 269 | protected production | KeychainHelper/KeychainBackupHelper.m | before/after SHA-256 and byte size match; protected diff empty |
| 270 | protected production | scripts/keychain_backup.sh | before/after SHA-256 and byte size match; protected diff empty |
| 271 | protected production | AppDataBackupManager.h | before/after SHA-256 and byte size match; protected diff empty |
| 272 | protected production | AppDataBackupManager.m | before/after SHA-256 and byte size match; protected diff empty |
| 273 | protected production | WeaponXKeychainBridge/Tweak.m | before/after SHA-256 and byte size match; protected diff empty |
| 274 | protected production | WeaponXKeychainBridge.plist | before/after SHA-256 and byte size match; protected diff empty |
| 275 | protected production | keychain_base_ent.plist | before/after SHA-256 and byte size match; protected diff empty |
| 276 | protected production | BackupKeychainGroupsViewController.h/.m | before/after SHA-256 and byte size match; protected diff empty |
| 277 | protected production | KeychainGroupsViewController.h/.m | before/after SHA-256 and byte size match; protected diff empty |
| 278 | protected production | ProjectXTweak/KeychainHooks.x | before/after SHA-256 and byte size match; protected diff empty |
| 279 | protected production | common/KeychainUUIDManager.h/.m | before/after SHA-256 and byte size match; protected diff empty |
| 280 | protected production | Phase-1 source | before/after SHA-256 and byte size match; protected diff empty |
| 281 | protected production | Phase-2 restore source | before/after SHA-256 and byte size match; protected diff empty |
| 282 | protected production | Phase-3 backup source | before/after SHA-256 and byte size match; protected diff empty |
| 283 | operation non-regression | SecItemCopyMatching sites | unchanged because KeychainBackupHelper/script/manager/bridge production files are byte-identical |
| 284 | operation non-regression | SecItemAdd sites | unchanged because KeychainBackupHelper/script/manager/bridge production files are byte-identical |
| 285 | operation non-regression | SecItemDelete sites | unchanged because KeychainBackupHelper/script/manager/bridge production files are byte-identical |
| 286 | operation non-regression | broad restore pre-wipe | unchanged because KeychainBackupHelper/script/manager/bridge production files are byte-identical |
| 287 | operation non-regression | temporary-directory behavior | unchanged because KeychainBackupHelper/script/manager/bridge production files are byte-identical |
| 288 | operation non-regression | entitlement extraction/resigning | unchanged because KeychainBackupHelper/script/manager/bridge production files are byte-identical |
| 289 | operation non-regression | access-group selection | unchanged because KeychainBackupHelper/script/manager/bridge production files are byte-identical |
| 290 | operation non-regression | human stdout logs | unchanged because KeychainBackupHelper/script/manager/bridge production files are byte-identical |
| 291 | operation non-regression | human stderr logs | unchanged because KeychainBackupHelper/script/manager/bridge production files are byte-identical |
| 292 | later-task boundary | TASK-4.2 exit redesign | not implemented |
| 293 | later-task boundary | TASK-4.3 broad pre-delete removal | not implemented |
| 294 | later-task boundary | TASK-4.4 exact item identity | not implemented |
| 295 | later-task boundary | TASK-4.5 per-item upsert | not implemented |
| 296 | later-task boundary | TASK-4.6 secure workspace/path validation | not implemented |
| 297 | later-task boundary | TASK-4.7 requested/effective groups | not implemented |
| 298 | later-task boundary | TASK-4.8 manager/bridge parsing | not implemented |
| 299 | later-task boundary | TASK-4.9 protection policy | not implemented |
| 300 | later-task boundary | Phase-5 UI | not implemented |
| 301 | later-task boundary | later-phase work | not implemented |
| 302 | script passthrough | scripts/keychain_backup.sh | byte-identical; no parsing or filtering added |
| 303 | manager integration | AppDataBackupManager.h/.m | byte-identical; zero structured-result parsing |
| 304 | bridge integration | WeaponXKeychainBridge/Tweak.m | byte-identical; zero structured-result parsing |
| 305 | Makefile | backup_helper_FILES | adds KeychainHelper/PXKeychainHelperResult.m exactly once and changes no other target setting |
| 306 | workspace hygiene | coordinator modified/untracked documentation | not staged, reverted, deleted, formatted, or rewritten |
| 307 | toolchain | Windows host lacks clang/make/xcrun/THEOS | Objective-C frontend/link/device execution remains pending |
| 308 | device risk | older Foundation binary-plist behavior | must be confirmed by GitHub Actions/device tests |
| 309 | device risk | stdout interleaving with wrapper capture | single-process ordered stdio expected; verify on target |
| 310 | device risk | very large helper counts | bounded result may intentionally emit INVALID while preserving legacy exit |
| 311 | device risk | NSError domain from platform/framework | control/lossless/255-byte validation may reject and trigger INVALID |
| 312 | device risk | binary plist canonical byte ordering | schema equality is semantic; exact bytes may vary by Foundation version |

## Protected production SHA-256 and byte size before/after
The protected baseline hashes and byte sizes come from the accepted TASK-3.10A report and are recaptured from the current workspace after TASK-4.1. The set includes every explicitly named protected Keychain/script/manager/bridge/UI file and every production source introduced or changed from TASK-1.1 through TASK-3.10A. Git diff independently confirms zero changes to every row.

| File | Before SHA-256 | Before bytes | After SHA-256 | After bytes | Match |
|---|---|---:|---|---:|---:|
| `AppDataBackupManager.h` | `b19c1c61e6df642468d713dede5a0c0bd0dbb6a0ac72d98ad6878d3cae1f2e75` | 1442 | `b19c1c61e6df642468d713dede5a0c0bd0dbb6a0ac72d98ad6878d3cae1f2e75` | 1442 | TRUE |
| `AppDataBackupManager.m` | `d6a302c90ab988a2c9b27c36fa664bc219082c6175f631942426b5fb91d2191e` | 221835 | `d6a302c90ab988a2c9b27c36fa664bc219082c6175f631942426b5fb91d2191e` | 221835 | TRUE |
| `AppDataCleaner.m` | `69549666233bbbd812f16ba5abae9bfa875e5d85723a2a8f82d63b54332d4c93` | 370484 | `69549666233bbbd812f16ba5abae9bfa875e5d85723a2a8f82d63b54332d4c93` | 370484 | TRUE |
| `AppGroupContainerResolver.h` | `c18f6e6dd09d19dd49564d442c956eb3be4a153118faff392cdd899846263c97` | 1356 | `c18f6e6dd09d19dd49564d442c956eb3be4a153118faff392cdd899846263c97` | 1356 | TRUE |
| `AppGroupContainerResolver.m` | `11646d96beec86f070ea49e0a803fb1bc669bc48af56135f1acd7c39a5439df1` | 11499 | `11646d96beec86f070ea49e0a803fb1bc669bc48af56135f1acd7c39a5439df1` | 11499 | TRUE |
| `BackupKeychainGroupsViewController.h` | `fc77d536ab2a573b598ac7ff72339a63229d68f15ae239b827cb4dd2a78c2377` | 159 | `fc77d536ab2a573b598ac7ff72339a63229d68f15ae239b827cb4dd2a78c2377` | 159 | TRUE |
| `BackupKeychainGroupsViewController.m` | `2f0590d7b51b05733f92c9df19c93953c2ab14fc8ca7380c43b4126ea60c4ccf` | 9567 | `2f0590d7b51b05733f92c9df19c93953c2ab14fc8ca7380c43b4126ea60c4ccf` | 9567 | TRUE |
| `KeychainGroupsViewController.h` | `48945d11fbf9ee4e9921140fc7d674abacbed3076db2b514fc641b6ac118a50b` | 153 | `48945d11fbf9ee4e9921140fc7d674abacbed3076db2b514fc641b6ac118a50b` | 153 | TRUE |
| `KeychainGroupsViewController.m` | `0e25b51199550964a5f743e50dc49641d161efd347973d49f58cc861a6260d35` | 10227 | `0e25b51199550964a5f743e50dc49641d161efd347973d49f58cc861a6260d35` | 10227 | TRUE |
| `KeychainHelper/KeychainBackupHelper.h` | `dbf0d5a4bdfc1df3e4f74b103968e018d0932f89c245bae8f260b196c0664281` | 4280 | `dbf0d5a4bdfc1df3e4f74b103968e018d0932f89c245bae8f260b196c0664281` | 4280 | TRUE |
| `KeychainHelper/KeychainBackupHelper.m` | `203884bf8d009a01a936acb5371c9316f7a0d6212b0d226f7f8a7661d51d122c` | 27970 | `203884bf8d009a01a936acb5371c9316f7a0d6212b0d226f7f8a7661d51d122c` | 27970 | TRUE |
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
| `PXBackupStaleWorkspaceCleanup.m` | `f96ed6b3be43b32ef4b31687fd10e797957d93f831fda58bfd39c3b3c26d4584` | 81407 | `f96ed6b3be43b32ef4b31687fd10e797957d93f831fda58bfd39c3b3c26d4584` | 81407 | TRUE |
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
| `ProjectXTweak/KeychainHooks.x` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 | TRUE |
| `ProjectXViewController.m` | `b7c5293dfa5d27fdc39c36f236f76306a855eaaf4e9e028f4c2111eb68146162` | 372278 | `b7c5293dfa5d27fdc39c36f236f76306a855eaaf4e9e028f4c2111eb68146162` | 372278 | TRUE |
| `WeaponXKeychainBridge.plist` | `e47d3b6c67ff941c9232d1fcf643bd94e81327cfd40244f1b5f38b99b918fe02` | 386 | `e47d3b6c67ff941c9232d1fcf643bd94e81327cfd40244f1b5f38b99b918fe02` | 386 | TRUE |
| `WeaponXKeychainBridge/Tweak.m` | `e0733e04eb4915a4753fe59247b17acd5e8cb7f8fa5fcf0bb8dee94f908459aa` | 21970 | `e0733e04eb4915a4753fe59247b17acd5e8cb7f8fa5fcf0bb8dee94f908459aa` | 21970 | TRUE |
| `common/KeychainUUIDManager.h` | `e1354e95536dc3218b3afbc3f198aad582285b0037717ca0fb5515048d8eb626` | 405 | `e1354e95536dc3218b3afbc3f198aad582285b0037717ca0fb5515048d8eb626` | 405 | TRUE |
| `common/KeychainUUIDManager.m` | `954bc45263985727851347397300ea31ff908e0464a5cf4efdf29a93df633e02` | 3479 | `954bc45263985727851347397300ea31ff908e0464a5cf4efdf29a93df633e02` | 3479 | TRUE |
| `keychain_base_ent.plist` | `8661cc558cb294239068ce2c24958dc2e717e80998c4f342ad1a9c463fb45496` | 912 | `8661cc558cb294239068ce2c24958dc2e717e80998c4f342ad1a9c463fb45496` | 912 | TRUE |
| `scripts/keychain_backup.sh` | `b3f05517ab230b9f37acfefe4c81568e3f88268c5e110653a50b3d30bd9437ae` | 32096 | `b3f05517ab230b9f37acfefe4c81568e3f88268c5e110653a50b3d30bd9437ae` | 32096 | TRUE |

## Full authorized production diff
The report excludes its own diff to avoid recursive self-embedding; the block below is the complete diff of all four authorized production files.
```diff
diff --git a/KeychainHelper/PXKeychainHelperResult.h b/KeychainHelper/PXKeychainHelperResult.h
new file mode 100644
index 0000000..220a314
--- /dev/null
+++ b/KeychainHelper/PXKeychainHelperResult.h
@@ -0,0 +1,70 @@
+#import <Foundation/Foundation.h>
+
+NS_ASSUME_NONNULL_BEGIN
+
+FOUNDATION_EXPORT NSInteger const PXKeychainHelperResultSchemaVersion;
+FOUNDATION_EXPORT NSString * const PXKeychainHelperResultOutputPrefix;
+FOUNDATION_EXPORT NSErrorDomain const PXKeychainHelperResultErrorDomain;
+FOUNDATION_EXPORT NSString * const PXKeychainHelperResultErrorFieldPathKey;
+
+typedef NS_ENUM(NSInteger, PXKeychainHelperOperation) {
+    PXKeychainHelperOperationUnknown = 0,
+    PXKeychainHelperOperationBackup = 1,
+    PXKeychainHelperOperationRestore = 2,
+    PXKeychainHelperOperationWipe = 3,
+    PXKeychainHelperOperationList = 4,
+};
+
+typedef NS_ENUM(NSInteger, PXKeychainHelperCompletion) {
+    PXKeychainHelperCompletionFailed = 1,
+    PXKeychainHelperCompletionCompleted = 2,
+    PXKeychainHelperCompletionPartial = 3,
+};
+
+typedef NS_ERROR_ENUM(PXKeychainHelperResultErrorDomain,
+                      PXKeychainHelperResultErrorCode) {
+    PXKeychainHelperResultErrorInvalidInput = 1,
+    PXKeychainHelperResultErrorInvalidOperation = 2,
+    PXKeychainHelperResultErrorInvalidCompletion = 3,
+    PXKeychainHelperResultErrorInvalidCounts = 4,
+    PXKeychainHelperResultErrorInvalidFatalError = 5,
+    PXKeychainHelperResultErrorLimitExceeded = 6,
+    PXKeychainHelperResultErrorSerializationFailed = 7,
+    PXKeychainHelperResultErrorInternalInvariantFailed = 8,
+};
+
+__attribute__((objc_subclassing_restricted))
+@interface PXKeychainHelperResult : NSObject <NSCopying>
+
+@property (nonatomic, readonly) NSInteger schemaVersion;
+@property (nonatomic, readonly) PXKeychainHelperOperation operation;
+@property (nonatomic, readonly) PXKeychainHelperCompletion completion;
+@property (nonatomic, readonly) NSUInteger attemptedCount;
+@property (nonatomic, readonly) NSUInteger succeededCount;
+@property (nonatomic, readonly) NSUInteger failedCount;
+@property (nonatomic, readonly) NSUInteger skippedCount;
+@property (nonatomic, readonly) NSUInteger warningCount;
+@property (nonatomic, readonly) NSUInteger errorCount;
+@property (nonatomic, readonly) BOOL fatalErrorPresent;
+@property (nonatomic, copy, readonly) NSString *fatalErrorDomain;
+@property (nonatomic, readonly) NSInteger fatalErrorCode;
+@property (nonatomic, copy, readonly) NSDictionary<NSString *, id> *propertyListRepresentation;
+@property (nonatomic, copy, readonly) NSString *machineReadableLine;
+
++ (nullable instancetype)resultWithOperation:(PXKeychainHelperOperation)operation
+                                  completion:(PXKeychainHelperCompletion)completion
+                              attemptedCount:(NSUInteger)attemptedCount
+                              succeededCount:(NSUInteger)succeededCount
+                                 failedCount:(NSUInteger)failedCount
+                                skippedCount:(NSUInteger)skippedCount
+                                warningCount:(NSUInteger)warningCount
+                                  errorCount:(NSUInteger)errorCount
+                                  fatalError:(NSError * _Nullable)fatalError
+                                       error:(NSError * _Nullable * _Nullable)error;
+
+- (instancetype)init NS_UNAVAILABLE;
++ (instancetype)new NS_UNAVAILABLE;
+
+@end
+
+NS_ASSUME_NONNULL_END
diff --git a/KeychainHelper/PXKeychainHelperResult.m b/KeychainHelper/PXKeychainHelperResult.m
new file mode 100644
index 0000000..593af3e
--- /dev/null
+++ b/KeychainHelper/PXKeychainHelperResult.m
@@ -0,0 +1,573 @@
+#import "PXKeychainHelperResult.h"
+#import <CoreFoundation/CoreFoundation.h>
+
+NSInteger const PXKeychainHelperResultSchemaVersion = 1;
+NSString * const PXKeychainHelperResultOutputPrefix = @"PXKEYCHAIN_HELPER_RESULT_V1=";
+NSErrorDomain const PXKeychainHelperResultErrorDomain = @"com.hydra.projectx.keychain-helper-result";
+NSString * const PXKeychainHelperResultErrorFieldPathKey = @"fieldPath";
+
+static const NSUInteger PXKeychainHelperResultMaximumCount = 1000000;
+static const NSUInteger PXKeychainHelperResultMaximumFatalDomainBytes = 255;
+static const NSUInteger PXKeychainHelperResultMaximumBinaryPlistBytes = 16 * 1024;
+static const NSUInteger PXKeychainHelperResultMaximumBase64Bytes = 24 * 1024;
+static const NSUInteger PXKeychainHelperResultMaximumOutputLineBytes = 25 * 1024;
+
+static void PXKeychainHelperResultSetError(NSError **error,
+                                            PXKeychainHelperResultErrorCode code,
+                                            NSString *fieldPath,
+                                            NSString *description) {
+    if (!error) {
+        return;
+    }
+    *error = [NSError errorWithDomain:PXKeychainHelperResultErrorDomain
+                                 code:code
+                             userInfo:@{
+                                 NSLocalizedDescriptionKey: description,
+                                 PXKeychainHelperResultErrorFieldPathKey: fieldPath,
+                             }];
+}
+
+static NSString *PXKeychainHelperOperationString(PXKeychainHelperOperation operation) {
+    switch (operation) {
+        case PXKeychainHelperOperationUnknown:
+            return @"unknown";
+        case PXKeychainHelperOperationBackup:
+            return @"backup";
+        case PXKeychainHelperOperationRestore:
+            return @"restore";
+        case PXKeychainHelperOperationWipe:
+            return @"wipe";
+        case PXKeychainHelperOperationList:
+            return @"list";
+    }
+    return nil;
+}
+
+static NSString *PXKeychainHelperCompletionString(PXKeychainHelperCompletion completion) {
+    switch (completion) {
+        case PXKeychainHelperCompletionFailed:
+            return @"failed";
+        case PXKeychainHelperCompletionCompleted:
+            return @"completed";
+        case PXKeychainHelperCompletionPartial:
+            return @"partial";
+    }
+    return nil;
+}
+
+static BOOL PXKeychainHelperResultCountIsWithinLimit(NSUInteger count) {
+    return count <= PXKeychainHelperResultMaximumCount;
+}
+
+static BOOL PXKeychainHelperResultCountsFitAttempted(NSUInteger attemptedCount,
+                                                      NSUInteger succeededCount,
+                                                      NSUInteger failedCount,
+                                                      NSUInteger skippedCount) {
+    if (succeededCount > attemptedCount) {
+        return NO;
+    }
+    NSUInteger remaining = attemptedCount - succeededCount;
+    if (failedCount > remaining) {
+        return NO;
+    }
+    remaining -= failedCount;
+    return skippedCount <= remaining;
+}
+
+static BOOL PXKeychainHelperResultFatalDomainIsValid(NSString *domain,
+                                                      NSUInteger *byteCountOut) {
+    if (![domain isKindOfClass:[NSString class]] || domain.length == 0) {
+        return NO;
+    }
+    NSData *utf8 = [domain dataUsingEncoding:NSUTF8StringEncoding
+                        allowLossyConversion:NO];
+    if (!utf8 || utf8.length == 0) {
+        return NO;
+    }
+    NSString *roundTrip = [[NSString alloc] initWithData:utf8
+                                                 encoding:NSUTF8StringEncoding];
+    if (!roundTrip || ![roundTrip isEqualToString:domain]) {
+        return NO;
+    }
+    unichar nulCharacter = 0;
+    NSString *nulString = [NSString stringWithCharacters:&nulCharacter length:1];
+    if ([domain rangeOfString:nulString].location != NSNotFound ||
+        [domain rangeOfCharacterFromSet:[NSCharacterSet controlCharacterSet]].location != NSNotFound) {
+        return NO;
+    }
+    if (byteCountOut) {
+        *byteCountOut = utf8.length;
+    }
+    return YES;
+}
+
+static BOOL PXKeychainHelperResultIsNumber(id value) {
+    return [value isKindOfClass:[NSNumber class]] &&
+           CFGetTypeID((__bridge CFTypeRef)value) == CFNumberGetTypeID();
+}
+
+static BOOL PXKeychainHelperResultIsBoolean(id value) {
+    return [value isKindOfClass:[NSNumber class]] &&
+           CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID();
+}
+
+static BOOL PXKeychainHelperResultRepresentationMatchesState(
+    NSDictionary<NSString *, id> *representation,
+    PXKeychainHelperOperation operation,
+    PXKeychainHelperCompletion completion,
+    NSUInteger attemptedCount,
+    NSUInteger succeededCount,
+    NSUInteger failedCount,
+    NSUInteger skippedCount,
+    NSUInteger warningCount,
+    NSUInteger errorCount,
+    BOOL fatalErrorPresent,
+    NSString *fatalErrorDomain,
+    NSInteger fatalErrorCode) {
+    if (![representation isKindOfClass:[NSDictionary class]] || representation.count != 10) {
+        return NO;
+    }
+    NSSet<NSString *> *rootKeys = [NSSet setWithArray:@[
+        @"schemaVersion",
+        @"operation",
+        @"completion",
+        @"attemptedCount",
+        @"succeededCount",
+        @"failedCount",
+        @"skippedCount",
+        @"warningCount",
+        @"errorCount",
+        @"fatalError",
+    ]];
+    if (![[NSSet setWithArray:representation.allKeys] isEqualToSet:rootKeys]) {
+        return NO;
+    }
+
+    NSNumber *schemaNumber = representation[@"schemaVersion"];
+    NSString *operationString = representation[@"operation"];
+    NSString *completionString = representation[@"completion"];
+    NSNumber *attemptedNumber = representation[@"attemptedCount"];
+    NSNumber *succeededNumber = representation[@"succeededCount"];
+    NSNumber *failedNumber = representation[@"failedCount"];
+    NSNumber *skippedNumber = representation[@"skippedCount"];
+    NSNumber *warningNumber = representation[@"warningCount"];
+    NSNumber *errorNumber = representation[@"errorCount"];
+    NSDictionary<NSString *, id> *fatalRepresentation = representation[@"fatalError"];
+
+    if (!PXKeychainHelperResultIsNumber(schemaNumber) ||
+        schemaNumber.integerValue != PXKeychainHelperResultSchemaVersion ||
+        ![operationString isEqualToString:PXKeychainHelperOperationString(operation)] ||
+        ![completionString isEqualToString:PXKeychainHelperCompletionString(completion)] ||
+        !PXKeychainHelperResultIsNumber(attemptedNumber) ||
+        attemptedNumber.unsignedIntegerValue != attemptedCount ||
+        !PXKeychainHelperResultIsNumber(succeededNumber) ||
+        succeededNumber.unsignedIntegerValue != succeededCount ||
+        !PXKeychainHelperResultIsNumber(failedNumber) ||
+        failedNumber.unsignedIntegerValue != failedCount ||
+        !PXKeychainHelperResultIsNumber(skippedNumber) ||
+        skippedNumber.unsignedIntegerValue != skippedCount ||
+        !PXKeychainHelperResultIsNumber(warningNumber) ||
+        warningNumber.unsignedIntegerValue != warningCount ||
+        !PXKeychainHelperResultIsNumber(errorNumber) ||
+        errorNumber.unsignedIntegerValue != errorCount ||
+        ![fatalRepresentation isKindOfClass:[NSDictionary class]] ||
+        fatalRepresentation.count != 3) {
+        return NO;
+    }
+
+    NSSet<NSString *> *fatalKeys = [NSSet setWithArray:@[
+        @"present",
+        @"domain",
+        @"code",
+    ]];
+    if (![[NSSet setWithArray:fatalRepresentation.allKeys] isEqualToSet:fatalKeys]) {
+        return NO;
+    }
+
+    NSNumber *presentNumber = fatalRepresentation[@"present"];
+    NSString *domain = fatalRepresentation[@"domain"];
+    NSNumber *codeNumber = fatalRepresentation[@"code"];
+    return PXKeychainHelperResultIsBoolean(presentNumber) &&
+           presentNumber.boolValue == fatalErrorPresent &&
+           [domain isKindOfClass:[NSString class]] &&
+           [domain isEqualToString:fatalErrorDomain] &&
+           PXKeychainHelperResultIsNumber(codeNumber) &&
+           codeNumber.integerValue == fatalErrorCode;
+}
+
+@interface PXKeychainHelperResult ()
+
+- (instancetype)px_initWithOperation:(PXKeychainHelperOperation)operation
+                          completion:(PXKeychainHelperCompletion)completion
+                      attemptedCount:(NSUInteger)attemptedCount
+                      succeededCount:(NSUInteger)succeededCount
+                         failedCount:(NSUInteger)failedCount
+                        skippedCount:(NSUInteger)skippedCount
+                        warningCount:(NSUInteger)warningCount
+                          errorCount:(NSUInteger)errorCount
+                   fatalErrorPresent:(BOOL)fatalErrorPresent
+                    fatalErrorDomain:(NSString *)fatalErrorDomain
+                      fatalErrorCode:(NSInteger)fatalErrorCode
+          propertyListRepresentation:(NSDictionary<NSString *, id> *)propertyListRepresentation
+                 machineReadableLine:(NSString *)machineReadableLine;
+
+@end
+
+@implementation PXKeychainHelperResult
+
++ (instancetype)resultWithOperation:(PXKeychainHelperOperation)operation
+                         completion:(PXKeychainHelperCompletion)completion
+                     attemptedCount:(NSUInteger)attemptedCount
+                     succeededCount:(NSUInteger)succeededCount
+                        failedCount:(NSUInteger)failedCount
+                       skippedCount:(NSUInteger)skippedCount
+                       warningCount:(NSUInteger)warningCount
+                         errorCount:(NSUInteger)errorCount
+                         fatalError:(NSError *)fatalError
+                              error:(NSError **)error {
+    if (error) {
+        *error = nil;
+    }
+
+    NSString *operationString = PXKeychainHelperOperationString(operation);
+    if (!operationString) {
+        PXKeychainHelperResultSetError(error,
+                                       PXKeychainHelperResultErrorInvalidOperation,
+                                       @"$.operation",
+                                       @"The helper operation is invalid.");
+        return nil;
+    }
+    NSString *completionString = PXKeychainHelperCompletionString(completion);
+    if (!completionString) {
+        PXKeychainHelperResultSetError(error,
+                                       PXKeychainHelperResultErrorInvalidCompletion,
+                                       @"$.completion",
+                                       @"The helper completion is invalid.");
+        return nil;
+    }
+
+    if (!PXKeychainHelperResultCountIsWithinLimit(attemptedCount) ||
+        !PXKeychainHelperResultCountIsWithinLimit(succeededCount) ||
+        !PXKeychainHelperResultCountIsWithinLimit(failedCount) ||
+        !PXKeychainHelperResultCountIsWithinLimit(skippedCount) ||
+        !PXKeychainHelperResultCountIsWithinLimit(warningCount) ||
+        !PXKeychainHelperResultCountIsWithinLimit(errorCount)) {
+        PXKeychainHelperResultSetError(error,
+                                       PXKeychainHelperResultErrorLimitExceeded,
+                                       @"$.counts",
+                                       @"A helper result count exceeds the fixed limit.");
+        return nil;
+    }
+    if (!PXKeychainHelperResultCountsFitAttempted(attemptedCount,
+                                                  succeededCount,
+                                                  failedCount,
+                                                  skippedCount)) {
+        PXKeychainHelperResultSetError(error,
+                                       PXKeychainHelperResultErrorInvalidCounts,
+                                       @"$.counts",
+                                       @"The helper result counts are inconsistent.");
+        return nil;
+    }
+
+    if (operation == PXKeychainHelperOperationUnknown &&
+        completion != PXKeychainHelperCompletionFailed) {
+        PXKeychainHelperResultSetError(error,
+                                       PXKeychainHelperResultErrorInvalidOperation,
+                                       @"$.operation",
+                                       @"An unknown operation must report failed completion.");
+        return nil;
+    }
+    if (completion == PXKeychainHelperCompletionFailed &&
+        ![fatalError isKindOfClass:[NSError class]]) {
+        PXKeychainHelperResultSetError(error,
+                                       PXKeychainHelperResultErrorInvalidFatalError,
+                                       @"$.fatalError",
+                                       @"Failed completion requires a fatal error.");
+        return nil;
+    }
+    if ((completion == PXKeychainHelperCompletionCompleted ||
+         completion == PXKeychainHelperCompletionPartial) && fatalError != nil) {
+        PXKeychainHelperResultSetError(error,
+                                       PXKeychainHelperResultErrorInvalidFatalError,
+                                       @"$.fatalError",
+                                       @"Nonfailed completion cannot retain a fatal error.");
+        return nil;
+    }
+    if (completion == PXKeychainHelperCompletionCompleted &&
+        (failedCount != 0 || skippedCount != 0 || warningCount != 0 || errorCount != 0)) {
+        PXKeychainHelperResultSetError(error,
+                                       PXKeychainHelperResultErrorInvalidCompletion,
+                                       @"$.completion",
+                                       @"Completed completion cannot contain issue counts.");
+        return nil;
+    }
+    if (completion == PXKeychainHelperCompletionPartial &&
+        failedCount == 0 && skippedCount == 0 && warningCount == 0 && errorCount == 0) {
+        PXKeychainHelperResultSetError(error,
+                                       PXKeychainHelperResultErrorInvalidCompletion,
+                                       @"$.completion",
+                                       @"Partial completion requires at least one issue count.");
+        return nil;
+    }
+
+    BOOL fatalErrorPresent = fatalError != nil;
+    NSString *fatalErrorDomain = @"";
+    NSInteger fatalErrorCode = 0;
+    if (fatalErrorPresent) {
+        NSString *domain = fatalError.domain;
+        NSUInteger domainByteCount = 0;
+        if (!PXKeychainHelperResultFatalDomainIsValid(domain, &domainByteCount)) {
+            PXKeychainHelperResultSetError(error,
+                                           PXKeychainHelperResultErrorInvalidFatalError,
+                                           @"$.fatalError.domain",
+                                           @"The fatal error domain is invalid.");
+            return nil;
+        }
+        if (domainByteCount > PXKeychainHelperResultMaximumFatalDomainBytes) {
+            PXKeychainHelperResultSetError(error,
+                                           PXKeychainHelperResultErrorLimitExceeded,
+                                           @"$.fatalError.domain",
+                                           @"The fatal error domain exceeds the fixed limit.");
+            return nil;
+        }
+        fatalErrorDomain = [domain copy];
+        fatalErrorCode = fatalError.code;
+    }
+
+    NSDictionary<NSString *, id> *fatalRepresentation = @{
+        @"present": @(fatalErrorPresent),
+        @"domain": [fatalErrorDomain copy],
+        @"code": @(fatalErrorCode),
+    };
+    NSDictionary<NSString *, id> *snapshot = @{
+        @"schemaVersion": @(PXKeychainHelperResultSchemaVersion),
+        @"operation": [operationString copy],
+        @"completion": [completionString copy],
+        @"attemptedCount": @(attemptedCount),
+        @"succeededCount": @(succeededCount),
+        @"failedCount": @(failedCount),
+        @"skippedCount": @(skippedCount),
+        @"warningCount": @(warningCount),
+        @"errorCount": @(errorCount),
+        @"fatalError": [fatalRepresentation copy],
+    };
+    snapshot = [snapshot copy];
+
+    if (!PXKeychainHelperResultRepresentationMatchesState(snapshot,
+                                                           operation,
+                                                           completion,
+                                                           attemptedCount,
+                                                           succeededCount,
+                                                           failedCount,
+                                                           skippedCount,
+                                                           warningCount,
+                                                           errorCount,
+                                                           fatalErrorPresent,
+                                                           fatalErrorDomain,
+                                                           fatalErrorCode)) {
+        PXKeychainHelperResultSetError(error,
+                                       PXKeychainHelperResultErrorInternalInvariantFailed,
+                                       @"$",
+                                       @"The helper result snapshot is inconsistent.");
+        return nil;
+    }
+
+    NSError *serializationError = nil;
+    NSData *binaryPlist = [NSPropertyListSerialization dataWithPropertyList:snapshot
+                                                                     format:NSPropertyListBinaryFormat_v1_0
+                                                                    options:0
+                                                                      error:&serializationError];
+    if (!binaryPlist || serializationError) {
+        PXKeychainHelperResultSetError(error,
+                                       PXKeychainHelperResultErrorSerializationFailed,
+                                       @"$",
+                                       @"The helper result could not be serialized.");
+        return nil;
+    }
+    if (binaryPlist.length == 0 ||
+        binaryPlist.length > PXKeychainHelperResultMaximumBinaryPlistBytes) {
+        PXKeychainHelperResultSetError(error,
+                                       PXKeychainHelperResultErrorLimitExceeded,
+                                       @"$",
+                                       @"The binary helper result exceeds the fixed limit.");
+        return nil;
+    }
+
+    NSString *base64 = [binaryPlist base64EncodedStringWithOptions:0];
+    NSData *base64Bytes = [base64 dataUsingEncoding:NSUTF8StringEncoding
+                               allowLossyConversion:NO];
+    if (!base64Bytes || base64Bytes.length == 0 ||
+        base64Bytes.length > PXKeychainHelperResultMaximumBase64Bytes ||
+        [base64 rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet]].location != NSNotFound) {
+        PXKeychainHelperResultSetError(error,
+                                       PXKeychainHelperResultErrorLimitExceeded,
+                                       @"$",
+                                       @"The encoded helper result exceeds the fixed limit.");
+        return nil;
+    }
+
+    NSData *decodedBinaryPlist = [[NSData alloc] initWithBase64EncodedString:base64 options:0];
+    if (![decodedBinaryPlist isEqualToData:binaryPlist]) {
+        PXKeychainHelperResultSetError(error,
+                                       PXKeychainHelperResultErrorInternalInvariantFailed,
+                                       @"$",
+                                       @"The encoded helper result failed round-trip validation.");
+        return nil;
+    }
+
+    NSError *readError = nil;
+    NSPropertyListFormat decodedFormat = NSPropertyListOpenStepFormat;
+    id decodedObject = [NSPropertyListSerialization propertyListWithData:decodedBinaryPlist
+                                                                  options:NSPropertyListImmutable
+                                                                   format:&decodedFormat
+                                                                    error:&readError];
+    if (readError || decodedFormat != NSPropertyListBinaryFormat_v1_0 ||
+        ![decodedObject isKindOfClass:[NSDictionary class]] ||
+        ![(NSDictionary *)decodedObject isEqualToDictionary:snapshot] ||
+        !PXKeychainHelperResultRepresentationMatchesState(decodedObject,
+                                                           operation,
+                                                           completion,
+                                                           attemptedCount,
+                                                           succeededCount,
+                                                           failedCount,
+                                                           skippedCount,
+                                                           warningCount,
+                                                           errorCount,
+                                                           fatalErrorPresent,
+                                                           fatalErrorDomain,
+                                                           fatalErrorCode)) {
+        PXKeychainHelperResultSetError(error,
+                                       PXKeychainHelperResultErrorInternalInvariantFailed,
+                                       @"$",
+                                       @"The helper result failed immutable read-back validation.");
+        return nil;
+    }
+
+    NSDictionary<NSString *, id> *immutableSnapshot = [(NSDictionary *)decodedObject copy];
+    NSString *machineReadableLine =
+        [PXKeychainHelperResultOutputPrefix stringByAppendingString:base64];
+    NSData *lineBytes = [machineReadableLine dataUsingEncoding:NSUTF8StringEncoding
+                                          allowLossyConversion:NO];
+    NSRange firstPrefix = [machineReadableLine rangeOfString:PXKeychainHelperResultOutputPrefix];
+    NSRange remainingRange = NSMakeRange(PXKeychainHelperResultOutputPrefix.length,
+                                         machineReadableLine.length - PXKeychainHelperResultOutputPrefix.length);
+    NSRange repeatedPrefix = [machineReadableLine rangeOfString:PXKeychainHelperResultOutputPrefix
+                                                       options:0
+                                                         range:remainingRange];
+    if (!lineBytes || lineBytes.length == 0 ||
+        lineBytes.length > PXKeychainHelperResultMaximumOutputLineBytes ||
+        firstPrefix.location != 0 || firstPrefix.length != PXKeychainHelperResultOutputPrefix.length ||
+        repeatedPrefix.location != NSNotFound ||
+        [machineReadableLine hasSuffix:@"\n"] ||
+        [machineReadableLine hasSuffix:@"\r"]) {
+        PXKeychainHelperResultSetError(error,
+                                       PXKeychainHelperResultErrorLimitExceeded,
+                                       @"$",
+                                       @"The complete helper result line exceeds the fixed limit.");
+        return nil;
+    }
+
+    PXKeychainHelperResult *result =
+        [[PXKeychainHelperResult alloc] px_initWithOperation:operation
+                                                 completion:completion
+                                             attemptedCount:attemptedCount
+                                             succeededCount:succeededCount
+                                                failedCount:failedCount
+                                               skippedCount:skippedCount
+                                               warningCount:warningCount
+                                                 errorCount:errorCount
+                                          fatalErrorPresent:fatalErrorPresent
+                                           fatalErrorDomain:fatalErrorDomain
+                                             fatalErrorCode:fatalErrorCode
+                                 propertyListRepresentation:immutableSnapshot
+                                        machineReadableLine:machineReadableLine];
+    if (!result) {
+        PXKeychainHelperResultSetError(error,
+                                       PXKeychainHelperResultErrorInternalInvariantFailed,
+                                       @"$",
+                                       @"The immutable helper result could not be initialized.");
+    }
+    return result;
+}
+
+- (instancetype)px_initWithOperation:(PXKeychainHelperOperation)operation
+                          completion:(PXKeychainHelperCompletion)completion
+                      attemptedCount:(NSUInteger)attemptedCount
+                      succeededCount:(NSUInteger)succeededCount
+                         failedCount:(NSUInteger)failedCount
+                        skippedCount:(NSUInteger)skippedCount
+                        warningCount:(NSUInteger)warningCount
+                          errorCount:(NSUInteger)errorCount
+                   fatalErrorPresent:(BOOL)fatalErrorPresent
+                    fatalErrorDomain:(NSString *)fatalErrorDomain
+                      fatalErrorCode:(NSInteger)fatalErrorCode
+          propertyListRepresentation:(NSDictionary<NSString *, id> *)propertyListRepresentation
+                 machineReadableLine:(NSString *)machineReadableLine {
+    self = [super init];
+    if (self) {
+        _schemaVersion = PXKeychainHelperResultSchemaVersion;
+        _operation = operation;
+        _completion = completion;
+        _attemptedCount = attemptedCount;
+        _succeededCount = succeededCount;
+        _failedCount = failedCount;
+        _skippedCount = skippedCount;
+        _warningCount = warningCount;
+        _errorCount = errorCount;
+        _fatalErrorPresent = fatalErrorPresent;
+        _fatalErrorDomain = [fatalErrorDomain copy];
+        _fatalErrorCode = fatalErrorCode;
+        _propertyListRepresentation = [propertyListRepresentation copy];
+        _machineReadableLine = [machineReadableLine copy];
+    }
+    return self;
+}
+
+- (id)copyWithZone:(NSZone *)zone {
+    (void)zone;
+    return self;
+}
+
+- (BOOL)isEqual:(id)object {
+    if (self == object) {
+        return YES;
+    }
+    if (![object isMemberOfClass:[PXKeychainHelperResult class]]) {
+        return NO;
+    }
+    PXKeychainHelperResult *other = object;
+    return self.schemaVersion == other.schemaVersion &&
+           self.operation == other.operation &&
+           self.completion == other.completion &&
+           self.attemptedCount == other.attemptedCount &&
+           self.succeededCount == other.succeededCount &&
+           self.failedCount == other.failedCount &&
+           self.skippedCount == other.skippedCount &&
+           self.warningCount == other.warningCount &&
+           self.errorCount == other.errorCount &&
+           self.fatalErrorPresent == other.fatalErrorPresent &&
+           [self.fatalErrorDomain isEqualToString:other.fatalErrorDomain] &&
+           self.fatalErrorCode == other.fatalErrorCode &&
+           [self.propertyListRepresentation isEqualToDictionary:other.propertyListRepresentation] &&
+           [self.machineReadableLine isEqualToString:other.machineReadableLine];
+}
+
+- (NSUInteger)hash {
+    NSUInteger value = self.propertyListRepresentation.hash;
+    value ^= self.machineReadableLine.hash;
+    value ^= self.fatalErrorDomain.hash;
+    value ^= (NSUInteger)self.schemaVersion;
+    value ^= (NSUInteger)self.operation;
+    value ^= (NSUInteger)self.completion;
+    value ^= self.attemptedCount;
+    value ^= self.succeededCount;
+    value ^= self.failedCount;
+    value ^= self.skippedCount;
+    value ^= self.warningCount;
+    value ^= self.errorCount;
+    value ^= (NSUInteger)self.fatalErrorPresent;
+    value ^= (NSUInteger)self.fatalErrorCode;
+    return value;
+}
+
+@end
diff --git a/KeychainHelper/backup_helper.m b/KeychainHelper/backup_helper.m
index 234684d..d050485 100644
--- a/KeychainHelper/backup_helper.m
+++ b/KeychainHelper/backup_helper.m
@@ -19,6 +19,7 @@

 #import <Foundation/Foundation.h>
 #import "KeychainBackupHelper.h"
+#import "PXKeychainHelperResult.h"

 typedef NS_ENUM(NSInteger, PXHelperAction) {
     PXHelperActionUnknown = 0,
@@ -120,6 +121,83 @@ static NSString *PXSafeString(id v) {
     return [[v description] ?: @"" copy];
 }

+static PXKeychainHelperOperation PXStructuredOperationForAction(PXHelperAction action) {
+    switch (action) {
+        case PXHelperActionBackup:
+            return PXKeychainHelperOperationBackup;
+        case PXHelperActionRestore:
+            return PXKeychainHelperOperationRestore;
+        case PXHelperActionWipe:
+            return PXKeychainHelperOperationWipe;
+        case PXHelperActionList:
+            return PXKeychainHelperOperationList;
+        case PXHelperActionUnknown:
+            return PXKeychainHelperOperationUnknown;
+    }
+    return PXKeychainHelperOperationUnknown;
+}
+
+static PXKeychainHelperCompletion PXStructuredCompletionForResult(PXKeychainBackupResult *result) {
+    if (!result) {
+        return PXKeychainHelperCompletionFailed;
+    }
+    if (result.itemsFailed > 0 || result.warnings.count > 0 || result.errors.count > 0) {
+        return PXKeychainHelperCompletionPartial;
+    }
+    return PXKeychainHelperCompletionCompleted;
+}
+
+static NSError *PXStructuredSyntheticError(PXKeychainBackupErrorCode code) {
+    return [NSError errorWithDomain:PXKeychainBackupErrorDomain code:code userInfo:nil];
+}
+
+static PXKeychainHelperResult *PXCreateStructuredResult(PXKeychainHelperOperation operation,
+                                                        PXKeychainHelperCompletion completion,
+                                                        PXKeychainBackupResult *result,
+                                                        NSUInteger listCount,
+                                                        NSError *fatalError) {
+    NSUInteger attemptedCount = 0;
+    NSUInteger succeededCount = 0;
+    NSUInteger failedCount = 0;
+    NSUInteger warningCount = 0;
+    NSUInteger errorCount = 0;
+    if (operation == PXKeychainHelperOperationList &&
+        completion == PXKeychainHelperCompletionCompleted) {
+        attemptedCount = listCount;
+        succeededCount = listCount;
+    } else if (result) {
+        attemptedCount = result.itemsProcessed;
+        succeededCount = result.itemsSucceeded;
+        failedCount = result.itemsFailed;
+        warningCount = result.warnings.count;
+        errorCount = result.errors.count;
+    }
+
+    NSError *constructionError = nil;
+    PXKeychainHelperResult *structuredResult =
+        [PXKeychainHelperResult resultWithOperation:operation
+                                         completion:completion
+                                     attemptedCount:attemptedCount
+                                     succeededCount:succeededCount
+                                        failedCount:failedCount
+                                       skippedCount:0
+                                       warningCount:warningCount
+                                         errorCount:errorCount
+                                         fatalError:fatalError
+                                              error:&constructionError];
+    (void)constructionError;
+    return structuredResult;
+}
+
+static void PXEmitStructuredResult(PXKeychainHelperResult *result) {
+    NSString *line = result.machineReadableLine;
+    if (!line.length) {
+        line = @"PXKEYCHAIN_HELPER_RESULT_V1=INVALID";
+    }
+    fprintf(stdout, "%s\n", [line UTF8String] ?: "");
+    fflush(stdout);
+}
+
 int main(int argc, const char *argv[]) {
     @autoreleasepool {
         // Parse arguments.
@@ -149,6 +227,11 @@ int main(int argc, const char *argv[]) {
         if (!actionStr.length) {
             logError(@"Missing required --action argument");
             printUsage(argv[0]);
+            PXEmitStructuredResult(PXCreateStructuredResult(PXKeychainHelperOperationUnknown,
+                                                            PXKeychainHelperCompletionFailed,
+                                                            nil,
+                                                            0,
+                                                            PXStructuredSyntheticError(PXKeychainBackupErrorInvalidArguments)));
             return 1;
         }

@@ -156,8 +239,14 @@ int main(int argc, const char *argv[]) {
         if (action == PXHelperActionUnknown) {
             logError(@"Unknown action: %@", actionStr);
             printUsage(argv[0]);
+            PXEmitStructuredResult(PXCreateStructuredResult(PXKeychainHelperOperationUnknown,
+                                                            PXKeychainHelperCompletionFailed,
+                                                            nil,
+                                                            0,
+                                                            PXStructuredSyntheticError(PXKeychainBackupErrorInvalidArguments)));
             return 1;
         }
+        PXKeychainHelperOperation structuredOperation = PXStructuredOperationForAction(action);

         NSString *filePath = args[@"file"];
         NSArray<NSString *> *groups = parseGroups(args[@"groups"]);
@@ -174,10 +263,20 @@ int main(int argc, const char *argv[]) {
             case PXHelperActionBackup: {
                 if (!filePath.length) {
                     logError(@"--file is required for backup");
+                    PXEmitStructuredResult(PXCreateStructuredResult(structuredOperation,
+                                                                    PXKeychainHelperCompletionFailed,
+                                                                    nil,
+                                                                    0,
+                                                                    PXStructuredSyntheticError(PXKeychainBackupErrorInvalidArguments)));
                     return 1;
                 }
                 if (!groups.count) {
                     logError(@"--groups is required for backup");
+                    PXEmitStructuredResult(PXCreateStructuredResult(structuredOperation,
+                                                                    PXKeychainHelperCompletionFailed,
+                                                                    nil,
+                                                                    0,
+                                                                    PXStructuredSyntheticError(PXKeychainBackupErrorNoAccessGroups)));
                     return 1;
                 }

@@ -189,6 +288,11 @@ int main(int argc, const char *argv[]) {

                 if (!result) {
                     logError(@"Backup failed: %@", error.localizedDescription);
+                    PXEmitStructuredResult(PXCreateStructuredResult(structuredOperation,
+                                                                    PXKeychainHelperCompletionFailed,
+                                                                    nil,
+                                                                    0,
+                                                                    error ?: PXStructuredSyntheticError(PXKeychainBackupErrorUnknown)));
                     return 2;
                 }

@@ -201,12 +305,22 @@ int main(int argc, const char *argv[]) {
                     NSString *warning = PXSafeString(warningObj);
                     fprintf(stderr, "[WARN] %s\n", [warning UTF8String] ?: "");
                 }
-                break;
+                PXEmitStructuredResult(PXCreateStructuredResult(structuredOperation,
+                                                                PXStructuredCompletionForResult(result),
+                                                                result,
+                                                                0,
+                                                                nil));
+                return 0;
             }

             case PXHelperActionRestore: {
                 if (!filePath.length) {
                     logError(@"--file is required for restore");
+                    PXEmitStructuredResult(PXCreateStructuredResult(structuredOperation,
+                                                                    PXKeychainHelperCompletionFailed,
+                                                                    nil,
+                                                                    0,
+                                                                    PXStructuredSyntheticError(PXKeychainBackupErrorInvalidArguments)));
                     return 1;
                 }

@@ -218,6 +332,11 @@ int main(int argc, const char *argv[]) {

                 if (!result) {
                     logError(@"Restore failed: %@", error.localizedDescription);
+                    PXEmitStructuredResult(PXCreateStructuredResult(structuredOperation,
+                                                                    PXKeychainHelperCompletionFailed,
+                                                                    nil,
+                                                                    0,
+                                                                    error ?: PXStructuredSyntheticError(PXKeychainBackupErrorUnknown)));
                     return 2;
                 }

@@ -234,12 +353,22 @@ int main(int argc, const char *argv[]) {
                     NSString *err = PXSafeString(errObj);
                     fprintf(stderr, "[ERR] %s\n", [err UTF8String] ?: "");
                 }
-                break;
+                PXEmitStructuredResult(PXCreateStructuredResult(structuredOperation,
+                                                                PXStructuredCompletionForResult(result),
+                                                                result,
+                                                                0,
+                                                                nil));
+                return 0;
             }

             case PXHelperActionWipe: {
                 if (!groups.count) {
                     logError(@"--groups is required for wipe");
+                    PXEmitStructuredResult(PXCreateStructuredResult(structuredOperation,
+                                                                    PXKeychainHelperCompletionFailed,
+                                                                    nil,
+                                                                    0,
+                                                                    PXStructuredSyntheticError(PXKeychainBackupErrorNoAccessGroups)));
                     return 1;
                 }

@@ -261,6 +390,11 @@ int main(int argc, const char *argv[]) {

                 if (!result) {
                     logError(@"Wipe failed: %@", error.localizedDescription);
+                    PXEmitStructuredResult(PXCreateStructuredResult(structuredOperation,
+                                                                    PXKeychainHelperCompletionFailed,
+                                                                    nil,
+                                                                    0,
+                                                                    error ?: PXStructuredSyntheticError(PXKeychainBackupErrorUnknown)));
                     return 2;
                 }

@@ -269,17 +403,32 @@ int main(int argc, const char *argv[]) {
                     fprintf(stderr, "[WARN] %s\n", [warning UTF8String] ?: "");
                 }
                 if (result.itemsFailed > 0 || result.warnings.count > 0) {
+                    PXEmitStructuredResult(PXCreateStructuredResult(structuredOperation,
+                                                                    PXStructuredCompletionForResult(result),
+                                                                    result,
+                                                                    0,
+                                                                    nil));
                     return 2;
                 }

                 logSuccess(@"Wipe complete: %lu items deleted",
                           (unsigned long)result.itemsSucceeded);
-                break;
+                PXEmitStructuredResult(PXCreateStructuredResult(structuredOperation,
+                                                                PXStructuredCompletionForResult(result),
+                                                                result,
+                                                                0,
+                                                                nil));
+                return 0;
             }

             case PXHelperActionList: {
                 if (!groups.count) {
                     logError(@"--groups is required for list");
+                    PXEmitStructuredResult(PXCreateStructuredResult(structuredOperation,
+                                                                    PXKeychainHelperCompletionFailed,
+                                                                    nil,
+                                                                    0,
+                                                                    PXStructuredSyntheticError(PXKeychainBackupErrorNoAccessGroups)));
                     return 1;
                 }

@@ -311,13 +460,21 @@ int main(int argc, const char *argv[]) {
                            [svc UTF8String] ?: "",
                            [acc UTF8String] ?: "");
                 }
-                break;
+                PXEmitStructuredResult(PXCreateStructuredResult(structuredOperation,
+                                                                PXKeychainHelperCompletionCompleted,
+                                                                nil,
+                                                                items.count,
+                                                                nil));
+                return 0;
             }

             default:
-                break;
+                PXEmitStructuredResult(PXCreateStructuredResult(PXKeychainHelperOperationUnknown,
+                                                                PXKeychainHelperCompletionFailed,
+                                                                nil,
+                                                                0,
+                                                                PXStructuredSyntheticError(PXKeychainBackupErrorInvalidArguments)));
+                return 0;
         }
-
-        return 0;
     }
 }
diff --git a/Makefile b/Makefile
index 4aea055..9916f34 100644
--- a/Makefile
+++ b/Makefile
@@ -38,7 +38,7 @@ WeaponXDaemon_CODESIGN_FLAGS = -Sent.plist
 WeaponXDaemon_LDFLAGS = -framework IOKit

 # Keychain Helper Tool - CLI for backup/restore/wipe keychain items
-backup_helper_FILES = KeychainHelper/backup_helper.m KeychainHelper/KeychainBackupHelper.m
+backup_helper_FILES = KeychainHelper/backup_helper.m KeychainHelper/KeychainBackupHelper.m KeychainHelper/PXKeychainHelperResult.m
 backup_helper_CFLAGS = -fobjc-arc -Wno-error=unused-variable
 backup_helper_FRAMEWORKS = Foundation Security
 backup_helper_INSTALL_PATH = /Library/WeaponX
```

## Whitespace, CRLF, and NUL audit
| File | Bytes | NUL | CRLF sequences | Final LF |
|---|---:|---:|---:|---:|
| `KeychainHelper/PXKeychainHelperResult.h` | 3191 | 0 | 0 | TRUE |
| `KeychainHelper/PXKeychainHelperResult.m` | 27477 | 0 | 0 | TRUE |
| `KeychainHelper/backup_helper.m` | 24800 | 0 | 480 | TRUE |
| `Makefile` | 9186 | 0 | 174 | TRUE |
- `git diff --check` reports no authorized whitespace errors. Existing CRLF style in `backup_helper.m` and `Makefile` is preserved; the two new Objective-C files and this report use UTF-8 LF. No authorized file contains NUL bytes, and every authorized text file ends with LF.

GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
