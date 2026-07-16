# TASK-4.2 REPORT - Define Reliable Keychain Helper Exit Codes

## Result
- Implementation status: COMPLETE within the authorized source scope.
- Source-review target: TASK-4.2 only.
- Baseline: `1a59e96258651aa9c6aa8d77a1e6debea67ab524`.
- TASK-4.1 prerequisite: ACCEPTED and COMPLETED.
- No TASK-4.3 or later work is included.

## Exact scope
| Status | Path | Purpose |
|---|---|---|
| A | `KeychainHelper/PXKeychainHelperExitCode.h` | exact 13-value exit taxonomy |
| M | `KeychainHelper/backup_helper.m` | direct-helper classification and one semantic finalizer |
| M | `scripts/keychain_backup.sh` | wrapper constants, pre-helper categories, and raw-status normalizer |
| A | `docs/backup-restore-hardening/reports/TASK-4.2-REPORT.md` | implementation and validation evidence |

## Baseline evidence
Commands recorded before implementation:
```text
git status --short --untracked-files=all
git rev-parse HEAD
git log -8 --oneline
git diff --check
```
Baseline HEAD output:
```text
1a59e96258651aa9c6aa8d77a1e6debea67ab524
```
Baseline status output (coordinator-owned modified/untracked documents retained and never staged or rewritten):
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
?? docs/backup-restore-hardening/reviews/TASK-4.1-REVIEW.md
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
?? docs/backup-restore-hardening/tasks/TASK-4.2-define-reliable-keychain-helper-exit-codes.md
```
Baseline log output:
```text
1a59e96 phase4(task-4.1): add structured keychain helper result
02770e2 phase3(task-3.10A): fix stale name classification and rollback errors
5e70a8f phase3(task-3.10): harden backup discovery and stale cleanup
aa01f73 phase3(task-3.9A): make cleanup removal race safe
aa47468 phase3(task-3.9): centralize backup failure cleanup
e55e9d6 phase3(task-3.8A): make directory publication no-replace
494cae0 phase3(task-3.8): publish completed backup atomically
bf9e518 phase3(task-3.7): write and validate manifest atomically
```
Baseline `git diff --check`: zero errors; Git emitted only existing CRLF conversion warnings for coordinator-owned documentation.

## Legacy direct-helper exit inventory
- Raw `return 0;`: 6.
- Raw `return 1;`: 7.
- Raw `return 2;`: 4.
- Raw `return 3;`: 0.
- Legacy business semantics mixed completed, partial, invalid-argument, and operation-failure states into 0/1/2; partial handling differed among backup, restore, and wipe.

## Legacy wrapper failure inventory
- Baseline shell contained 24 standalone `return 1` statements and 5 standalone `exit 1` statements.
- Baseline forwarded all four helper child statuses raw, including legacy 1/2/3, shell execution statuses, signal-derived statuses, and future unknown statuses.
- Baseline did not distinguish helper, target, entitlement, workspace, signing, or dependency availability.

## Exact enum and direct/wrapper partition
| Enum | Value | Direct helper | Wrapper |
|---|---:|---:|---:|
| `PXKeychainHelperExitCodeCompleted` | 0 | yes | yes |
| `PXKeychainHelperExitCodePartial` | 10 | yes | yes |
| `PXKeychainHelperExitCodeInvalidArguments` | 20 | yes | yes |
| `PXKeychainHelperExitCodeInvalidInput` | 21 | yes | yes |
| `PXKeychainHelperExitCodeAccessDenied` | 30 | yes | yes |
| `PXKeychainHelperExitCodeOperationFailed` | 40 | yes | yes |
| `PXKeychainHelperExitCodeProtocolFailure` | 50 | yes | yes |
| `PXKeychainHelperExitCodeHelperUnavailable` | 60 | no | yes |
| `PXKeychainHelperExitCodeTargetUnavailable` | 61 | no | yes |
| `PXKeychainHelperExitCodeEntitlementFailure` | 62 | no | yes |
| `PXKeychainHelperExitCodeWorkspaceFailure` | 63 | no | yes |
| `PXKeychainHelperExitCodeSigningFailure` | 64 | no | yes |
| `PXKeychainHelperExitCodeDependencyUnavailable` | 65 | no | yes |
- Direct helper can terminate only with `0, 10, 20, 21, 30, 40, 50`.
- Wrapper-only setup categories are `60-65`; none appears in `backup_helper.m`.

## Completion-to-exit mapping
| Completion | Compatible exit |
|---|---:|
| Completed | 0 |
| Partial | 10 |
| Failed | 20, 21, 30, or 40 |
| nil/missing/mismatched result | 50 with INVALID line |

## Fatal-error category mapping
| Exact fatal fact | Direct exit |
|---|---:|
| `PXKeychainBackupErrorDomain` + InvalidArguments | 20 |
| `PXKeychainBackupErrorDomain` + NoAccessGroups | 20 |
| Restore + FileIO | 21 |
| Restore + InvalidBackupFile | 21 |
| exact domain + SecurityFramework | 30 |
| Backup FileIO or InvalidBackupFile | 40 |
| Unknown, future code, foreign domain, nil/synthetic Unknown | 40 |
- Classification reads only `fatalError.domain`, `fatalError.code`, and operation. It does not parse localized descriptions, warnings, stderr, or OSStatus text.
- A nonfatal Partial result remains exit 10 even if its warnings/errors describe Security behavior.

## ProtocolFailure precedence and one-finalizer proof
- `PXFinalizeStructuredResult` is defined exactly once.
- Every non-help terminal path returns through it; 16 finalizer call sites were counted.
- The existing emitter is defined exactly once and is called only by the finalizer.
- Finalizer validates non-nil result, nonempty prefixed line without CR/LF, valid completion, and completion/exit compatibility.
- Construction failure, absent/empty line, invalid completion, or mismatched intended exit emits `PXKEYCHAIN_HELPER_RESULT_V1=INVALID` and returns 50, overriding the intended business exit.
- `--help` retains current usage output, returns 0, and bypasses result emission.

## Direct-helper terminal paths
| # | Finalizer call site | Structured state | Selected exit |
|---:|---|---|---:|
| 1 | missing `--action` | Unknown / Failed | 20 |
| 2 | unknown `--action` | Unknown / Failed | 20 |
| 3 | backup missing `--file` | Backup / Failed | 20 |
| 4 | backup missing `--groups` | Backup / Failed | 20 |
| 5 | backup fatal result nil | Backup / Failed | 20, 30, or 40 by exact fatal facts |
| 6 | backup terminal result | Backup / Completed or Partial | 0 or 10 |
| 7 | restore missing `--file` | Restore / Failed | 20 |
| 8 | restore fatal result nil | Restore / Failed | 20, 21, 30, or 40 by exact fatal facts |
| 9 | restore terminal result | Restore / Completed or Partial | 0 or 10 |
| 10 | wipe missing `--groups` | Wipe / Failed | 20 |
| 11 | wipe fatal result nil | Wipe / Failed | 20, 30, or 40 by exact fatal facts |
| 12 | wipe failed-item/warning Partial branch | Wipe / Partial | 10 |
| 13 | wipe remaining terminal result | Wipe / Completed or errors-only Partial | 0 or 10 |
| 14 | list missing `--groups` | List / Failed | 20 |
| 15 | list success | List / Completed | 0 |
| 16 | unreachable switch default | Unknown / Failed | 20 |

## Shell constants
- Exactly thirteen non-exported `readonly PX_KEYCHAIN_EXIT_*` constants mirror the Objective-C enum values 0, 10, 20, 21, 30, 40, 50, and 60-65.
- No constant is exported into the child helper environment.

## Wrapper pre-helper mappings
| Wrapper fact | Exit |
|---|---:|
| installed helper nonexecutable | 60 |
| missing action | 20 |
| missing bundle ID | 20 |
| unknown action | 20 |
| backup output argument missing | 20 |
| restore input argument missing | 20 |
| restore source precheck missing file | 21 |
| backup target absent | 61 |
| restore target absent | 61 |
| wipe target absent | 61 |
| list target absent | 61 |
| ldid absent during extraction | 65 |
| entitlement extraction output absent | 62 |
| helper entitlement generation absent | 62 |
| backup derived groups empty | 62 |
| wipe derived groups empty | 62 |
| copy helper fails in backup | 63 |
| copy helper fails in restore | 63 |
| copy helper fails in wipe | 63 |
| copy helper fails in list | 63 |
| resign binary missing | 63 |
| resign entitlement input missing | 62 |
| ldid absent during resign | 65 |
| ldid execution nonzero | 64 |
| optional plutil fallback unavailable | existing fallback retained; no new hard failure |

## Recognized-child passthrough and normalization
- Exactly one `normalize_helper_exit_status` function is defined.
- It is called immediately after each of the four helper executions: backup, restore, wipe, and list.
- Raw `0, 10, 20, 21, 30, 40, 50` pass through unchanged.
- Every other shell child status in 0-255, including 1, 2, 3, 126, 127, signal-derived values, and future unknown values, logs the bounded numeric `$?` and returns 40.
- The wrapper does not emit, parse, decode, filter, remove, or reorder the structured-result line or human stdout/stderr.

## Caller consequences and zero integration
- `AppDataBackupManager.m`, `AppDataCleaner.m`, and `WeaponXKeychainBridge/Tweak.m` are byte-identical and contain no new exact-code switch or result parser.
- Current manager and cleaner paths remain zero/nonzero consumers; therefore Partial 10 fails closed until TASK-4.8.
- Current Restore warning-only aggregate policy is unchanged.
- Current Clear failure accounting is unchanged.

## TASK-4.1 protocol freeze
- `PXKeychainHelperResult.h` and `.m` are byte-identical.
- No `exitCode` field was added to the payload.
- Schema version 1, ten root keys, three fatal-error keys, binary plist/base64 framing, privacy exclusions, fixed bounds, and output prefix are unchanged.

## Keychain core and Security/pre-wipe freeze
- `KeychainBackupHelper.h/.m` are byte-identical.
- `SecItemCopyMatching`, `SecItemAdd`, `SecItemDelete`, broad restore pre-wipe, backup file schema, item counts, warnings, and errors are unchanged.

## Wrapper behavior retained
- `TEMP_DIR`, cleanup trap, mkdir/cp/chmod paths, entitlement content, target discovery, application-identifier fallback, selected groups, helper argv, and overwrite forwarding remain unchanged except for explicit failure-status propagation.
- Existing optional plutil fallback behavior is retained and was not converted into a new hard failure.
- No new path or workspace validation was added.

## Later-task boundaries
- Not implemented: TASK-4.3 broad pre-delete removal; TASK-4.4 exact identity; TASK-4.5 per-item upsert; TASK-4.6 path hardening; TASK-4.7 requested/effective groups; TASK-4.8 parsing/integration; TASK-4.9 backup protection; bridge unification; rollback; UI, manifest, or later phases.

## Static gates
| Gate | Observed | Required | Result |
|---|---:|---:|---|
| header enum definitions | 1 | 1 | PASS |
| header enum values | 13 | 13 | PASS |
| direct finalizer definitions | 1 | 1 | PASS |
| emitter definitions | 1 | 1 | PASS |
| emitter call sites outside definition | 1 | 1 | PASS |
| non-help finalizer calls | 16 | 16 | PASS |
| raw direct `return 1;` | 0 | 0 | PASS |
| raw direct `return 2;` | 0 | 0 | PASS |
| raw direct `return 3;` | 0 | 0 | PASS |
| wrapper-only direct references | 0 | 0 | PASS |
| result-line fprintf | 1 | 1 | PASS |
| fflush stdout | 1 | 1 | PASS |
| INVALID literal | 1 | 1 | PASS |
| shell readonly constants | 13 | 13 | PASS |
| exported shell constants | 0 | 0 | PASS |
| normalizer definitions | 1 | 1 | PASS |
| normalizer operation calls | 4 | 4 | PASS |
| structured prefix references in shell | 0 | 0 | PASS |
| protected files checked | 74 | 74 | PASS |
| semantic model assertions | 10112 | 10112 | PASS |
- `git diff --check` on authorized production files: PASS.
- Objective-C delimiter/quote lexical balance: PASS.
- Target discovery and helper argv/overwrite/TEMP_DIR/trap/mkdir/chmod static identity checks: PASS.

## Shell syntax and static validation
- `C:\Program Files\Git\bin\bash.exe -n scripts/keychain_backup.sh`: PASS (exit 0).
- `C:\Program Files\Git\usr\bin\bash.exe -n scripts/keychain_backup.sh`: PASS (exit 0).
- Independent normalizer model exhaustively checked all 256 shell statuses.

## Explicit numbered scenario matrix
Explicit scenarios: 580.
| # | Area | Stimulus | Expected result |
|---:|---|---|---|
| 1 | direct terminal | missing --action | Unknown / Failed; InvalidArguments; exit 20; exactly one finalizer emission |
| 2 | direct terminal | unknown --action | Unknown / Failed; InvalidArguments; exit 20; exactly one finalizer emission |
| 3 | direct terminal | backup missing --file | Backup / Failed; InvalidArguments; exit 20; exactly one finalizer emission |
| 4 | direct terminal | backup missing --groups | Backup / Failed; InvalidArguments; exit 20; exactly one finalizer emission |
| 5 | direct terminal | backup fatal result nil | Backup / Failed; fatal domain/code classifier; exit 20, 30, or 40; exactly one finalizer emission |
| 6 | direct terminal | backup nonfatal Completed | Backup / Completed; completion mapping; exit 0; exactly one finalizer emission |
| 7 | direct terminal | backup nonfatal Partial | Backup / Partial; completion mapping; exit 10; exactly one finalizer emission |
| 8 | direct terminal | restore missing --file | Restore / Failed; InvalidArguments; exit 20; exactly one finalizer emission |
| 9 | direct terminal | restore fatal result nil | Restore / Failed; fatal domain/code classifier; exit 20, 21, 30, or 40; exactly one finalizer emission |
| 10 | direct terminal | restore nonfatal Completed | Restore / Completed; completion mapping; exit 0; exactly one finalizer emission |
| 11 | direct terminal | restore nonfatal Partial | Restore / Partial; completion mapping; exit 10; exactly one finalizer emission |
| 12 | direct terminal | wipe missing --groups | Wipe / Failed; InvalidArguments; exit 20; exactly one finalizer emission |
| 13 | direct terminal | wipe fatal result nil | Wipe / Failed; fatal domain/code classifier; exit 20, 30, or 40; exactly one finalizer emission |
| 14 | direct terminal | wipe nonfatal Completed | Wipe / Completed; completion mapping; exit 0; exactly one finalizer emission |
| 15 | direct terminal | wipe nonfatal Partial | Wipe / Partial; completion mapping; exit 10; exactly one finalizer emission |
| 16 | direct terminal | list missing --groups / list success / unreachable default | Failed or Completed; finalizer-selected direct code; exit 20 or 0; exactly one finalizer emission |
| 17 | fatal category | operation=backup; domain=PXKeychainBackupErrorDomain; code=-1 | exit 40 using domain/code only |
| 18 | fatal category | operation=backup; domain=PXKeychainBackupErrorDomain; code=0 | exit 40 using domain/code only |
| 19 | fatal category | operation=backup; domain=PXKeychainBackupErrorDomain; code=1 | exit 20 using domain/code only |
| 20 | fatal category | operation=backup; domain=PXKeychainBackupErrorDomain; code=2 | exit 20 using domain/code only |
| 21 | fatal category | operation=backup; domain=PXKeychainBackupErrorDomain; code=3 | exit 30 using domain/code only |
| 22 | fatal category | operation=backup; domain=PXKeychainBackupErrorDomain; code=4 | exit 40 using domain/code only |
| 23 | fatal category | operation=backup; domain=PXKeychainBackupErrorDomain; code=5 | exit 40 using domain/code only |
| 24 | fatal category | operation=backup; domain=PXKeychainBackupErrorDomain; code=6 | exit 40 using domain/code only |
| 25 | fatal category | operation=backup; domain=PXKeychainBackupErrorDomain; code=127 | exit 40 using domain/code only |
| 26 | fatal category | operation=backup; domain=PXKeychainBackupErrorDomain; code=999 | exit 40 using domain/code only |
| 27 | fatal category | operation=backup; domain=foreign.domain; code=-1 | exit 40 using domain/code only |
| 28 | fatal category | operation=backup; domain=foreign.domain; code=0 | exit 40 using domain/code only |
| 29 | fatal category | operation=backup; domain=foreign.domain; code=1 | exit 40 using domain/code only |
| 30 | fatal category | operation=backup; domain=foreign.domain; code=2 | exit 40 using domain/code only |
| 31 | fatal category | operation=backup; domain=foreign.domain; code=3 | exit 40 using domain/code only |
| 32 | fatal category | operation=backup; domain=foreign.domain; code=4 | exit 40 using domain/code only |
| 33 | fatal category | operation=backup; domain=foreign.domain; code=5 | exit 40 using domain/code only |
| 34 | fatal category | operation=backup; domain=foreign.domain; code=6 | exit 40 using domain/code only |
| 35 | fatal category | operation=backup; domain=foreign.domain; code=127 | exit 40 using domain/code only |
| 36 | fatal category | operation=backup; domain=foreign.domain; code=999 | exit 40 using domain/code only |
| 37 | fatal category | operation=backup; domain=empty-domain; code=-1 | exit 40 using domain/code only |
| 38 | fatal category | operation=backup; domain=empty-domain; code=0 | exit 40 using domain/code only |
| 39 | fatal category | operation=backup; domain=empty-domain; code=1 | exit 40 using domain/code only |
| 40 | fatal category | operation=backup; domain=empty-domain; code=2 | exit 40 using domain/code only |
| 41 | fatal category | operation=backup; domain=empty-domain; code=3 | exit 40 using domain/code only |
| 42 | fatal category | operation=backup; domain=empty-domain; code=4 | exit 40 using domain/code only |
| 43 | fatal category | operation=backup; domain=empty-domain; code=5 | exit 40 using domain/code only |
| 44 | fatal category | operation=backup; domain=empty-domain; code=6 | exit 40 using domain/code only |
| 45 | fatal category | operation=backup; domain=empty-domain; code=127 | exit 40 using domain/code only |
| 46 | fatal category | operation=backup; domain=empty-domain; code=999 | exit 40 using domain/code only |
| 47 | fatal category | operation=restore; domain=PXKeychainBackupErrorDomain; code=-1 | exit 40 using domain/code only |
| 48 | fatal category | operation=restore; domain=PXKeychainBackupErrorDomain; code=0 | exit 40 using domain/code only |
| 49 | fatal category | operation=restore; domain=PXKeychainBackupErrorDomain; code=1 | exit 20 using domain/code only |
| 50 | fatal category | operation=restore; domain=PXKeychainBackupErrorDomain; code=2 | exit 20 using domain/code only |
| 51 | fatal category | operation=restore; domain=PXKeychainBackupErrorDomain; code=3 | exit 30 using domain/code only |
| 52 | fatal category | operation=restore; domain=PXKeychainBackupErrorDomain; code=4 | exit 21 using domain/code only |
| 53 | fatal category | operation=restore; domain=PXKeychainBackupErrorDomain; code=5 | exit 21 using domain/code only |
| 54 | fatal category | operation=restore; domain=PXKeychainBackupErrorDomain; code=6 | exit 40 using domain/code only |
| 55 | fatal category | operation=restore; domain=PXKeychainBackupErrorDomain; code=127 | exit 40 using domain/code only |
| 56 | fatal category | operation=restore; domain=PXKeychainBackupErrorDomain; code=999 | exit 40 using domain/code only |
| 57 | fatal category | operation=restore; domain=foreign.domain; code=-1 | exit 40 using domain/code only |
| 58 | fatal category | operation=restore; domain=foreign.domain; code=0 | exit 40 using domain/code only |
| 59 | fatal category | operation=restore; domain=foreign.domain; code=1 | exit 40 using domain/code only |
| 60 | fatal category | operation=restore; domain=foreign.domain; code=2 | exit 40 using domain/code only |
| 61 | fatal category | operation=restore; domain=foreign.domain; code=3 | exit 40 using domain/code only |
| 62 | fatal category | operation=restore; domain=foreign.domain; code=4 | exit 40 using domain/code only |
| 63 | fatal category | operation=restore; domain=foreign.domain; code=5 | exit 40 using domain/code only |
| 64 | fatal category | operation=restore; domain=foreign.domain; code=6 | exit 40 using domain/code only |
| 65 | fatal category | operation=restore; domain=foreign.domain; code=127 | exit 40 using domain/code only |
| 66 | fatal category | operation=restore; domain=foreign.domain; code=999 | exit 40 using domain/code only |
| 67 | fatal category | operation=restore; domain=empty-domain; code=-1 | exit 40 using domain/code only |
| 68 | fatal category | operation=restore; domain=empty-domain; code=0 | exit 40 using domain/code only |
| 69 | fatal category | operation=restore; domain=empty-domain; code=1 | exit 40 using domain/code only |
| 70 | fatal category | operation=restore; domain=empty-domain; code=2 | exit 40 using domain/code only |
| 71 | fatal category | operation=restore; domain=empty-domain; code=3 | exit 40 using domain/code only |
| 72 | fatal category | operation=restore; domain=empty-domain; code=4 | exit 40 using domain/code only |
| 73 | fatal category | operation=restore; domain=empty-domain; code=5 | exit 40 using domain/code only |
| 74 | fatal category | operation=restore; domain=empty-domain; code=6 | exit 40 using domain/code only |
| 75 | fatal category | operation=restore; domain=empty-domain; code=127 | exit 40 using domain/code only |
| 76 | fatal category | operation=restore; domain=empty-domain; code=999 | exit 40 using domain/code only |
| 77 | fatal category | operation=wipe; domain=PXKeychainBackupErrorDomain; code=-1 | exit 40 using domain/code only |
| 78 | fatal category | operation=wipe; domain=PXKeychainBackupErrorDomain; code=0 | exit 40 using domain/code only |
| 79 | fatal category | operation=wipe; domain=PXKeychainBackupErrorDomain; code=1 | exit 20 using domain/code only |
| 80 | fatal category | operation=wipe; domain=PXKeychainBackupErrorDomain; code=2 | exit 20 using domain/code only |
| 81 | fatal category | operation=wipe; domain=PXKeychainBackupErrorDomain; code=3 | exit 30 using domain/code only |
| 82 | fatal category | operation=wipe; domain=PXKeychainBackupErrorDomain; code=4 | exit 40 using domain/code only |
| 83 | fatal category | operation=wipe; domain=PXKeychainBackupErrorDomain; code=5 | exit 40 using domain/code only |
| 84 | fatal category | operation=wipe; domain=PXKeychainBackupErrorDomain; code=6 | exit 40 using domain/code only |
| 85 | fatal category | operation=wipe; domain=PXKeychainBackupErrorDomain; code=127 | exit 40 using domain/code only |
| 86 | fatal category | operation=wipe; domain=PXKeychainBackupErrorDomain; code=999 | exit 40 using domain/code only |
| 87 | fatal category | operation=wipe; domain=foreign.domain; code=-1 | exit 40 using domain/code only |
| 88 | fatal category | operation=wipe; domain=foreign.domain; code=0 | exit 40 using domain/code only |
| 89 | fatal category | operation=wipe; domain=foreign.domain; code=1 | exit 40 using domain/code only |
| 90 | fatal category | operation=wipe; domain=foreign.domain; code=2 | exit 40 using domain/code only |
| 91 | fatal category | operation=wipe; domain=foreign.domain; code=3 | exit 40 using domain/code only |
| 92 | fatal category | operation=wipe; domain=foreign.domain; code=4 | exit 40 using domain/code only |
| 93 | fatal category | operation=wipe; domain=foreign.domain; code=5 | exit 40 using domain/code only |
| 94 | fatal category | operation=wipe; domain=foreign.domain; code=6 | exit 40 using domain/code only |
| 95 | fatal category | operation=wipe; domain=foreign.domain; code=127 | exit 40 using domain/code only |
| 96 | fatal category | operation=wipe; domain=foreign.domain; code=999 | exit 40 using domain/code only |
| 97 | fatal category | operation=wipe; domain=empty-domain; code=-1 | exit 40 using domain/code only |
| 98 | fatal category | operation=wipe; domain=empty-domain; code=0 | exit 40 using domain/code only |
| 99 | fatal category | operation=wipe; domain=empty-domain; code=1 | exit 40 using domain/code only |
| 100 | fatal category | operation=wipe; domain=empty-domain; code=2 | exit 40 using domain/code only |
| 101 | fatal category | operation=wipe; domain=empty-domain; code=3 | exit 40 using domain/code only |
| 102 | fatal category | operation=wipe; domain=empty-domain; code=4 | exit 40 using domain/code only |
| 103 | fatal category | operation=wipe; domain=empty-domain; code=5 | exit 40 using domain/code only |
| 104 | fatal category | operation=wipe; domain=empty-domain; code=6 | exit 40 using domain/code only |
| 105 | fatal category | operation=wipe; domain=empty-domain; code=127 | exit 40 using domain/code only |
| 106 | fatal category | operation=wipe; domain=empty-domain; code=999 | exit 40 using domain/code only |
| 107 | fatal category | operation=list; domain=PXKeychainBackupErrorDomain; code=-1 | exit 40 using domain/code only |
| 108 | fatal category | operation=list; domain=PXKeychainBackupErrorDomain; code=0 | exit 40 using domain/code only |
| 109 | fatal category | operation=list; domain=PXKeychainBackupErrorDomain; code=1 | exit 20 using domain/code only |
| 110 | fatal category | operation=list; domain=PXKeychainBackupErrorDomain; code=2 | exit 20 using domain/code only |
| 111 | fatal category | operation=list; domain=PXKeychainBackupErrorDomain; code=3 | exit 30 using domain/code only |
| 112 | fatal category | operation=list; domain=PXKeychainBackupErrorDomain; code=4 | exit 40 using domain/code only |
| 113 | fatal category | operation=list; domain=PXKeychainBackupErrorDomain; code=5 | exit 40 using domain/code only |
| 114 | fatal category | operation=list; domain=PXKeychainBackupErrorDomain; code=6 | exit 40 using domain/code only |
| 115 | fatal category | operation=list; domain=PXKeychainBackupErrorDomain; code=127 | exit 40 using domain/code only |
| 116 | fatal category | operation=list; domain=PXKeychainBackupErrorDomain; code=999 | exit 40 using domain/code only |
| 117 | fatal category | operation=list; domain=foreign.domain; code=-1 | exit 40 using domain/code only |
| 118 | fatal category | operation=list; domain=foreign.domain; code=0 | exit 40 using domain/code only |
| 119 | fatal category | operation=list; domain=foreign.domain; code=1 | exit 40 using domain/code only |
| 120 | fatal category | operation=list; domain=foreign.domain; code=2 | exit 40 using domain/code only |
| 121 | fatal category | operation=list; domain=foreign.domain; code=3 | exit 40 using domain/code only |
| 122 | fatal category | operation=list; domain=foreign.domain; code=4 | exit 40 using domain/code only |
| 123 | fatal category | operation=list; domain=foreign.domain; code=5 | exit 40 using domain/code only |
| 124 | fatal category | operation=list; domain=foreign.domain; code=6 | exit 40 using domain/code only |
| 125 | fatal category | operation=list; domain=foreign.domain; code=127 | exit 40 using domain/code only |
| 126 | fatal category | operation=list; domain=foreign.domain; code=999 | exit 40 using domain/code only |
| 127 | fatal category | operation=list; domain=empty-domain; code=-1 | exit 40 using domain/code only |
| 128 | fatal category | operation=list; domain=empty-domain; code=0 | exit 40 using domain/code only |
| 129 | fatal category | operation=list; domain=empty-domain; code=1 | exit 40 using domain/code only |
| 130 | fatal category | operation=list; domain=empty-domain; code=2 | exit 40 using domain/code only |
| 131 | fatal category | operation=list; domain=empty-domain; code=3 | exit 40 using domain/code only |
| 132 | fatal category | operation=list; domain=empty-domain; code=4 | exit 40 using domain/code only |
| 133 | fatal category | operation=list; domain=empty-domain; code=5 | exit 40 using domain/code only |
| 134 | fatal category | operation=list; domain=empty-domain; code=6 | exit 40 using domain/code only |
| 135 | fatal category | operation=list; domain=empty-domain; code=127 | exit 40 using domain/code only |
| 136 | fatal category | operation=list; domain=empty-domain; code=999 | exit 40 using domain/code only |
| 137 | fatal category | operation=unknown; domain=PXKeychainBackupErrorDomain; code=-1 | exit 40 using domain/code only |
| 138 | fatal category | operation=unknown; domain=PXKeychainBackupErrorDomain; code=0 | exit 40 using domain/code only |
| 139 | fatal category | operation=unknown; domain=PXKeychainBackupErrorDomain; code=1 | exit 20 using domain/code only |
| 140 | fatal category | operation=unknown; domain=PXKeychainBackupErrorDomain; code=2 | exit 20 using domain/code only |
| 141 | fatal category | operation=unknown; domain=PXKeychainBackupErrorDomain; code=3 | exit 30 using domain/code only |
| 142 | fatal category | operation=unknown; domain=PXKeychainBackupErrorDomain; code=4 | exit 40 using domain/code only |
| 143 | fatal category | operation=unknown; domain=PXKeychainBackupErrorDomain; code=5 | exit 40 using domain/code only |
| 144 | fatal category | operation=unknown; domain=PXKeychainBackupErrorDomain; code=6 | exit 40 using domain/code only |
| 145 | fatal category | operation=unknown; domain=PXKeychainBackupErrorDomain; code=127 | exit 40 using domain/code only |
| 146 | fatal category | operation=unknown; domain=PXKeychainBackupErrorDomain; code=999 | exit 40 using domain/code only |
| 147 | fatal category | operation=unknown; domain=foreign.domain; code=-1 | exit 40 using domain/code only |
| 148 | fatal category | operation=unknown; domain=foreign.domain; code=0 | exit 40 using domain/code only |
| 149 | fatal category | operation=unknown; domain=foreign.domain; code=1 | exit 40 using domain/code only |
| 150 | fatal category | operation=unknown; domain=foreign.domain; code=2 | exit 40 using domain/code only |
| 151 | fatal category | operation=unknown; domain=foreign.domain; code=3 | exit 40 using domain/code only |
| 152 | fatal category | operation=unknown; domain=foreign.domain; code=4 | exit 40 using domain/code only |
| 153 | fatal category | operation=unknown; domain=foreign.domain; code=5 | exit 40 using domain/code only |
| 154 | fatal category | operation=unknown; domain=foreign.domain; code=6 | exit 40 using domain/code only |
| 155 | fatal category | operation=unknown; domain=foreign.domain; code=127 | exit 40 using domain/code only |
| 156 | fatal category | operation=unknown; domain=foreign.domain; code=999 | exit 40 using domain/code only |
| 157 | fatal category | operation=unknown; domain=empty-domain; code=-1 | exit 40 using domain/code only |
| 158 | fatal category | operation=unknown; domain=empty-domain; code=0 | exit 40 using domain/code only |
| 159 | fatal category | operation=unknown; domain=empty-domain; code=1 | exit 40 using domain/code only |
| 160 | fatal category | operation=unknown; domain=empty-domain; code=2 | exit 40 using domain/code only |
| 161 | fatal category | operation=unknown; domain=empty-domain; code=3 | exit 40 using domain/code only |
| 162 | fatal category | operation=unknown; domain=empty-domain; code=4 | exit 40 using domain/code only |
| 163 | fatal category | operation=unknown; domain=empty-domain; code=5 | exit 40 using domain/code only |
| 164 | fatal category | operation=unknown; domain=empty-domain; code=6 | exit 40 using domain/code only |
| 165 | fatal category | operation=unknown; domain=empty-domain; code=127 | exit 40 using domain/code only |
| 166 | fatal category | operation=unknown; domain=empty-domain; code=999 | exit 40 using domain/code only |
| 167 | finalizer compatibility | completion=Completed; intended=0; valid machine line | exit 0; machine line |
| 168 | finalizer compatibility | completion=Completed; intended=10; valid machine line | exit 50; INVALID line |
| 169 | finalizer compatibility | completion=Completed; intended=20; valid machine line | exit 50; INVALID line |
| 170 | finalizer compatibility | completion=Completed; intended=21; valid machine line | exit 50; INVALID line |
| 171 | finalizer compatibility | completion=Completed; intended=30; valid machine line | exit 50; INVALID line |
| 172 | finalizer compatibility | completion=Completed; intended=40; valid machine line | exit 50; INVALID line |
| 173 | finalizer compatibility | completion=Completed; intended=50; valid machine line | exit 50; INVALID line |
| 174 | finalizer compatibility | completion=Completed; intended=60; valid machine line | exit 50; INVALID line |
| 175 | finalizer compatibility | completion=Completed; intended=61; valid machine line | exit 50; INVALID line |
| 176 | finalizer compatibility | completion=Completed; intended=62; valid machine line | exit 50; INVALID line |
| 177 | finalizer compatibility | completion=Completed; intended=63; valid machine line | exit 50; INVALID line |
| 178 | finalizer compatibility | completion=Completed; intended=64; valid machine line | exit 50; INVALID line |
| 179 | finalizer compatibility | completion=Completed; intended=65; valid machine line | exit 50; INVALID line |
| 180 | finalizer compatibility | completion=Partial; intended=0; valid machine line | exit 50; INVALID line |
| 181 | finalizer compatibility | completion=Partial; intended=10; valid machine line | exit 10; machine line |
| 182 | finalizer compatibility | completion=Partial; intended=20; valid machine line | exit 50; INVALID line |
| 183 | finalizer compatibility | completion=Partial; intended=21; valid machine line | exit 50; INVALID line |
| 184 | finalizer compatibility | completion=Partial; intended=30; valid machine line | exit 50; INVALID line |
| 185 | finalizer compatibility | completion=Partial; intended=40; valid machine line | exit 50; INVALID line |
| 186 | finalizer compatibility | completion=Partial; intended=50; valid machine line | exit 50; INVALID line |
| 187 | finalizer compatibility | completion=Partial; intended=60; valid machine line | exit 50; INVALID line |
| 188 | finalizer compatibility | completion=Partial; intended=61; valid machine line | exit 50; INVALID line |
| 189 | finalizer compatibility | completion=Partial; intended=62; valid machine line | exit 50; INVALID line |
| 190 | finalizer compatibility | completion=Partial; intended=63; valid machine line | exit 50; INVALID line |
| 191 | finalizer compatibility | completion=Partial; intended=64; valid machine line | exit 50; INVALID line |
| 192 | finalizer compatibility | completion=Partial; intended=65; valid machine line | exit 50; INVALID line |
| 193 | finalizer compatibility | completion=Failed; intended=0; valid machine line | exit 50; INVALID line |
| 194 | finalizer compatibility | completion=Failed; intended=10; valid machine line | exit 50; INVALID line |
| 195 | finalizer compatibility | completion=Failed; intended=20; valid machine line | exit 20; machine line |
| 196 | finalizer compatibility | completion=Failed; intended=21; valid machine line | exit 21; machine line |
| 197 | finalizer compatibility | completion=Failed; intended=30; valid machine line | exit 30; machine line |
| 198 | finalizer compatibility | completion=Failed; intended=40; valid machine line | exit 40; machine line |
| 199 | finalizer compatibility | completion=Failed; intended=50; valid machine line | exit 50; INVALID line |
| 200 | finalizer compatibility | completion=Failed; intended=60; valid machine line | exit 50; INVALID line |
| 201 | finalizer compatibility | completion=Failed; intended=61; valid machine line | exit 50; INVALID line |
| 202 | finalizer compatibility | completion=Failed; intended=62; valid machine line | exit 50; INVALID line |
| 203 | finalizer compatibility | completion=Failed; intended=63; valid machine line | exit 50; INVALID line |
| 204 | finalizer compatibility | completion=Failed; intended=64; valid machine line | exit 50; INVALID line |
| 205 | finalizer compatibility | completion=Failed; intended=65; valid machine line | exit 50; INVALID line |
| 206 | finalizer compatibility | completion=Invalid; intended=0; valid machine line | exit 50; INVALID line |
| 207 | finalizer compatibility | completion=Invalid; intended=10; valid machine line | exit 50; INVALID line |
| 208 | finalizer compatibility | completion=Invalid; intended=20; valid machine line | exit 50; INVALID line |
| 209 | finalizer compatibility | completion=Invalid; intended=21; valid machine line | exit 50; INVALID line |
| 210 | finalizer compatibility | completion=Invalid; intended=30; valid machine line | exit 50; INVALID line |
| 211 | finalizer compatibility | completion=Invalid; intended=40; valid machine line | exit 50; INVALID line |
| 212 | finalizer compatibility | completion=Invalid; intended=50; valid machine line | exit 50; INVALID line |
| 213 | finalizer compatibility | completion=Invalid; intended=60; valid machine line | exit 50; INVALID line |
| 214 | finalizer compatibility | completion=Invalid; intended=61; valid machine line | exit 50; INVALID line |
| 215 | finalizer compatibility | completion=Invalid; intended=62; valid machine line | exit 50; INVALID line |
| 216 | finalizer compatibility | completion=Invalid; intended=63; valid machine line | exit 50; INVALID line |
| 217 | finalizer compatibility | completion=Invalid; intended=64; valid machine line | exit 50; INVALID line |
| 218 | finalizer compatibility | completion=Invalid; intended=65; valid machine line | exit 50; INVALID line |
| 219 | protocol precedence | nil result; intended=0 | INVALID machine line; exit 50 overrides business code |
| 220 | protocol precedence | nil result; intended=10 | INVALID machine line; exit 50 overrides business code |
| 221 | protocol precedence | nil result; intended=20 | INVALID machine line; exit 50 overrides business code |
| 222 | protocol precedence | nil result; intended=21 | INVALID machine line; exit 50 overrides business code |
| 223 | protocol precedence | nil result; intended=30 | INVALID machine line; exit 50 overrides business code |
| 224 | protocol precedence | nil result; intended=40 | INVALID machine line; exit 50 overrides business code |
| 225 | protocol precedence | nil result; intended=50 | INVALID machine line; exit 50 overrides business code |
| 226 | protocol precedence | empty machine line; intended=0 | INVALID machine line; exit 50 overrides business code |
| 227 | protocol precedence | empty machine line; intended=10 | INVALID machine line; exit 50 overrides business code |
| 228 | protocol precedence | empty machine line; intended=20 | INVALID machine line; exit 50 overrides business code |
| 229 | protocol precedence | empty machine line; intended=21 | INVALID machine line; exit 50 overrides business code |
| 230 | protocol precedence | empty machine line; intended=30 | INVALID machine line; exit 50 overrides business code |
| 231 | protocol precedence | empty machine line; intended=40 | INVALID machine line; exit 50 overrides business code |
| 232 | protocol precedence | empty machine line; intended=50 | INVALID machine line; exit 50 overrides business code |
| 233 | protocol precedence | prefix-only line; intended=0 | INVALID machine line; exit 50 overrides business code |
| 234 | protocol precedence | prefix-only line; intended=10 | INVALID machine line; exit 50 overrides business code |
| 235 | protocol precedence | prefix-only line; intended=20 | INVALID machine line; exit 50 overrides business code |
| 236 | protocol precedence | prefix-only line; intended=21 | INVALID machine line; exit 50 overrides business code |
| 237 | protocol precedence | prefix-only line; intended=30 | INVALID machine line; exit 50 overrides business code |
| 238 | protocol precedence | prefix-only line; intended=40 | INVALID machine line; exit 50 overrides business code |
| 239 | protocol precedence | prefix-only line; intended=50 | INVALID machine line; exit 50 overrides business code |
| 240 | protocol precedence | line with LF; intended=0 | INVALID machine line; exit 50 overrides business code |
| 241 | protocol precedence | line with LF; intended=10 | INVALID machine line; exit 50 overrides business code |
| 242 | protocol precedence | line with LF; intended=20 | INVALID machine line; exit 50 overrides business code |
| 243 | protocol precedence | line with LF; intended=21 | INVALID machine line; exit 50 overrides business code |
| 244 | protocol precedence | line with LF; intended=30 | INVALID machine line; exit 50 overrides business code |
| 245 | protocol precedence | line with LF; intended=40 | INVALID machine line; exit 50 overrides business code |
| 246 | protocol precedence | line with LF; intended=50 | INVALID machine line; exit 50 overrides business code |
| 247 | protocol precedence | line with CR; intended=0 | INVALID machine line; exit 50 overrides business code |
| 248 | protocol precedence | line with CR; intended=10 | INVALID machine line; exit 50 overrides business code |
| 249 | protocol precedence | line with CR; intended=20 | INVALID machine line; exit 50 overrides business code |
| 250 | protocol precedence | line with CR; intended=21 | INVALID machine line; exit 50 overrides business code |
| 251 | protocol precedence | line with CR; intended=30 | INVALID machine line; exit 50 overrides business code |
| 252 | protocol precedence | line with CR; intended=40 | INVALID machine line; exit 50 overrides business code |
| 253 | protocol precedence | line with CR; intended=50 | INVALID machine line; exit 50 overrides business code |
| 254 | protocol precedence | invalid completion enum; intended=0 | INVALID machine line; exit 50 overrides business code |
| 255 | protocol precedence | invalid completion enum; intended=10 | INVALID machine line; exit 50 overrides business code |
| 256 | protocol precedence | invalid completion enum; intended=20 | INVALID machine line; exit 50 overrides business code |
| 257 | protocol precedence | invalid completion enum; intended=21 | INVALID machine line; exit 50 overrides business code |
| 258 | protocol precedence | invalid completion enum; intended=30 | INVALID machine line; exit 50 overrides business code |
| 259 | protocol precedence | invalid completion enum; intended=40 | INVALID machine line; exit 50 overrides business code |
| 260 | protocol precedence | invalid completion enum; intended=50 | INVALID machine line; exit 50 overrides business code |
| 261 | wrapper pre-helper | installed helper nonexecutable | wrapper result 60 |
| 262 | wrapper pre-helper | missing action | wrapper result 20 |
| 263 | wrapper pre-helper | missing bundle ID | wrapper result 20 |
| 264 | wrapper pre-helper | unknown action | wrapper result 20 |
| 265 | wrapper pre-helper | backup output argument missing | wrapper result 20 |
| 266 | wrapper pre-helper | restore input argument missing | wrapper result 20 |
| 267 | wrapper pre-helper | restore source precheck missing file | wrapper result 21 |
| 268 | wrapper pre-helper | backup target absent | wrapper result 61 |
| 269 | wrapper pre-helper | restore target absent | wrapper result 61 |
| 270 | wrapper pre-helper | wipe target absent | wrapper result 61 |
| 271 | wrapper pre-helper | list target absent | wrapper result 61 |
| 272 | wrapper pre-helper | ldid absent during extraction | wrapper result 65 |
| 273 | wrapper pre-helper | entitlement extraction output absent | wrapper result 62 |
| 274 | wrapper pre-helper | helper entitlement generation absent | wrapper result 62 |
| 275 | wrapper pre-helper | backup derived groups empty | wrapper result 62 |
| 276 | wrapper pre-helper | wipe derived groups empty | wrapper result 62 |
| 277 | wrapper pre-helper | copy helper fails in backup | wrapper result 63 |
| 278 | wrapper pre-helper | copy helper fails in restore | wrapper result 63 |
| 279 | wrapper pre-helper | copy helper fails in wipe | wrapper result 63 |
| 280 | wrapper pre-helper | copy helper fails in list | wrapper result 63 |
| 281 | wrapper pre-helper | resign binary missing | wrapper result 63 |
| 282 | wrapper pre-helper | resign entitlement input missing | wrapper result 62 |
| 283 | wrapper pre-helper | ldid absent during resign | wrapper result 65 |
| 284 | wrapper pre-helper | ldid execution nonzero | wrapper result 64 |
| 285 | wrapper pre-helper | optional plutil fallback unavailable | wrapper result existing fallback retained; no new hard failure |
| 286 | child normalization | raw child status=0 | normalized status=0; pass-through |
| 287 | child normalization | raw child status=1 | normalized status=40; bounded numeric log + OperationFailed |
| 288 | child normalization | raw child status=2 | normalized status=40; bounded numeric log + OperationFailed |
| 289 | child normalization | raw child status=3 | normalized status=40; bounded numeric log + OperationFailed |
| 290 | child normalization | raw child status=4 | normalized status=40; bounded numeric log + OperationFailed |
| 291 | child normalization | raw child status=5 | normalized status=40; bounded numeric log + OperationFailed |
| 292 | child normalization | raw child status=6 | normalized status=40; bounded numeric log + OperationFailed |
| 293 | child normalization | raw child status=7 | normalized status=40; bounded numeric log + OperationFailed |
| 294 | child normalization | raw child status=8 | normalized status=40; bounded numeric log + OperationFailed |
| 295 | child normalization | raw child status=9 | normalized status=40; bounded numeric log + OperationFailed |
| 296 | child normalization | raw child status=10 | normalized status=10; pass-through |
| 297 | child normalization | raw child status=11 | normalized status=40; bounded numeric log + OperationFailed |
| 298 | child normalization | raw child status=12 | normalized status=40; bounded numeric log + OperationFailed |
| 299 | child normalization | raw child status=13 | normalized status=40; bounded numeric log + OperationFailed |
| 300 | child normalization | raw child status=14 | normalized status=40; bounded numeric log + OperationFailed |
| 301 | child normalization | raw child status=15 | normalized status=40; bounded numeric log + OperationFailed |
| 302 | child normalization | raw child status=16 | normalized status=40; bounded numeric log + OperationFailed |
| 303 | child normalization | raw child status=17 | normalized status=40; bounded numeric log + OperationFailed |
| 304 | child normalization | raw child status=18 | normalized status=40; bounded numeric log + OperationFailed |
| 305 | child normalization | raw child status=19 | normalized status=40; bounded numeric log + OperationFailed |
| 306 | child normalization | raw child status=20 | normalized status=20; pass-through |
| 307 | child normalization | raw child status=21 | normalized status=21; pass-through |
| 308 | child normalization | raw child status=22 | normalized status=40; bounded numeric log + OperationFailed |
| 309 | child normalization | raw child status=23 | normalized status=40; bounded numeric log + OperationFailed |
| 310 | child normalization | raw child status=24 | normalized status=40; bounded numeric log + OperationFailed |
| 311 | child normalization | raw child status=25 | normalized status=40; bounded numeric log + OperationFailed |
| 312 | child normalization | raw child status=26 | normalized status=40; bounded numeric log + OperationFailed |
| 313 | child normalization | raw child status=27 | normalized status=40; bounded numeric log + OperationFailed |
| 314 | child normalization | raw child status=28 | normalized status=40; bounded numeric log + OperationFailed |
| 315 | child normalization | raw child status=29 | normalized status=40; bounded numeric log + OperationFailed |
| 316 | child normalization | raw child status=30 | normalized status=30; pass-through |
| 317 | child normalization | raw child status=31 | normalized status=40; bounded numeric log + OperationFailed |
| 318 | child normalization | raw child status=32 | normalized status=40; bounded numeric log + OperationFailed |
| 319 | child normalization | raw child status=33 | normalized status=40; bounded numeric log + OperationFailed |
| 320 | child normalization | raw child status=34 | normalized status=40; bounded numeric log + OperationFailed |
| 321 | child normalization | raw child status=35 | normalized status=40; bounded numeric log + OperationFailed |
| 322 | child normalization | raw child status=36 | normalized status=40; bounded numeric log + OperationFailed |
| 323 | child normalization | raw child status=37 | normalized status=40; bounded numeric log + OperationFailed |
| 324 | child normalization | raw child status=38 | normalized status=40; bounded numeric log + OperationFailed |
| 325 | child normalization | raw child status=39 | normalized status=40; bounded numeric log + OperationFailed |
| 326 | child normalization | raw child status=40 | normalized status=40; pass-through |
| 327 | child normalization | raw child status=41 | normalized status=40; bounded numeric log + OperationFailed |
| 328 | child normalization | raw child status=42 | normalized status=40; bounded numeric log + OperationFailed |
| 329 | child normalization | raw child status=43 | normalized status=40; bounded numeric log + OperationFailed |
| 330 | child normalization | raw child status=44 | normalized status=40; bounded numeric log + OperationFailed |
| 331 | child normalization | raw child status=45 | normalized status=40; bounded numeric log + OperationFailed |
| 332 | child normalization | raw child status=46 | normalized status=40; bounded numeric log + OperationFailed |
| 333 | child normalization | raw child status=47 | normalized status=40; bounded numeric log + OperationFailed |
| 334 | child normalization | raw child status=48 | normalized status=40; bounded numeric log + OperationFailed |
| 335 | child normalization | raw child status=49 | normalized status=40; bounded numeric log + OperationFailed |
| 336 | child normalization | raw child status=50 | normalized status=50; pass-through |
| 337 | child normalization | raw child status=51 | normalized status=40; bounded numeric log + OperationFailed |
| 338 | child normalization | raw child status=52 | normalized status=40; bounded numeric log + OperationFailed |
| 339 | child normalization | raw child status=53 | normalized status=40; bounded numeric log + OperationFailed |
| 340 | child normalization | raw child status=54 | normalized status=40; bounded numeric log + OperationFailed |
| 341 | child normalization | raw child status=55 | normalized status=40; bounded numeric log + OperationFailed |
| 342 | child normalization | raw child status=56 | normalized status=40; bounded numeric log + OperationFailed |
| 343 | child normalization | raw child status=57 | normalized status=40; bounded numeric log + OperationFailed |
| 344 | child normalization | raw child status=58 | normalized status=40; bounded numeric log + OperationFailed |
| 345 | child normalization | raw child status=59 | normalized status=40; bounded numeric log + OperationFailed |
| 346 | child normalization | raw child status=60 | normalized status=40; bounded numeric log + OperationFailed |
| 347 | child normalization | raw child status=61 | normalized status=40; bounded numeric log + OperationFailed |
| 348 | child normalization | raw child status=62 | normalized status=40; bounded numeric log + OperationFailed |
| 349 | child normalization | raw child status=63 | normalized status=40; bounded numeric log + OperationFailed |
| 350 | child normalization | raw child status=64 | normalized status=40; bounded numeric log + OperationFailed |
| 351 | child normalization | raw child status=65 | normalized status=40; bounded numeric log + OperationFailed |
| 352 | child normalization | raw child status=66 | normalized status=40; bounded numeric log + OperationFailed |
| 353 | child normalization | raw child status=67 | normalized status=40; bounded numeric log + OperationFailed |
| 354 | child normalization | raw child status=68 | normalized status=40; bounded numeric log + OperationFailed |
| 355 | child normalization | raw child status=69 | normalized status=40; bounded numeric log + OperationFailed |
| 356 | child normalization | raw child status=70 | normalized status=40; bounded numeric log + OperationFailed |
| 357 | child normalization | raw child status=71 | normalized status=40; bounded numeric log + OperationFailed |
| 358 | child normalization | raw child status=72 | normalized status=40; bounded numeric log + OperationFailed |
| 359 | child normalization | raw child status=73 | normalized status=40; bounded numeric log + OperationFailed |
| 360 | child normalization | raw child status=74 | normalized status=40; bounded numeric log + OperationFailed |
| 361 | child normalization | raw child status=75 | normalized status=40; bounded numeric log + OperationFailed |
| 362 | child normalization | raw child status=76 | normalized status=40; bounded numeric log + OperationFailed |
| 363 | child normalization | raw child status=77 | normalized status=40; bounded numeric log + OperationFailed |
| 364 | child normalization | raw child status=78 | normalized status=40; bounded numeric log + OperationFailed |
| 365 | child normalization | raw child status=79 | normalized status=40; bounded numeric log + OperationFailed |
| 366 | child normalization | raw child status=80 | normalized status=40; bounded numeric log + OperationFailed |
| 367 | child normalization | raw child status=81 | normalized status=40; bounded numeric log + OperationFailed |
| 368 | child normalization | raw child status=82 | normalized status=40; bounded numeric log + OperationFailed |
| 369 | child normalization | raw child status=83 | normalized status=40; bounded numeric log + OperationFailed |
| 370 | child normalization | raw child status=84 | normalized status=40; bounded numeric log + OperationFailed |
| 371 | child normalization | raw child status=85 | normalized status=40; bounded numeric log + OperationFailed |
| 372 | child normalization | raw child status=86 | normalized status=40; bounded numeric log + OperationFailed |
| 373 | child normalization | raw child status=87 | normalized status=40; bounded numeric log + OperationFailed |
| 374 | child normalization | raw child status=88 | normalized status=40; bounded numeric log + OperationFailed |
| 375 | child normalization | raw child status=89 | normalized status=40; bounded numeric log + OperationFailed |
| 376 | child normalization | raw child status=90 | normalized status=40; bounded numeric log + OperationFailed |
| 377 | child normalization | raw child status=91 | normalized status=40; bounded numeric log + OperationFailed |
| 378 | child normalization | raw child status=92 | normalized status=40; bounded numeric log + OperationFailed |
| 379 | child normalization | raw child status=93 | normalized status=40; bounded numeric log + OperationFailed |
| 380 | child normalization | raw child status=94 | normalized status=40; bounded numeric log + OperationFailed |
| 381 | child normalization | raw child status=95 | normalized status=40; bounded numeric log + OperationFailed |
| 382 | child normalization | raw child status=96 | normalized status=40; bounded numeric log + OperationFailed |
| 383 | child normalization | raw child status=97 | normalized status=40; bounded numeric log + OperationFailed |
| 384 | child normalization | raw child status=98 | normalized status=40; bounded numeric log + OperationFailed |
| 385 | child normalization | raw child status=99 | normalized status=40; bounded numeric log + OperationFailed |
| 386 | child normalization | raw child status=100 | normalized status=40; bounded numeric log + OperationFailed |
| 387 | child normalization | raw child status=101 | normalized status=40; bounded numeric log + OperationFailed |
| 388 | child normalization | raw child status=102 | normalized status=40; bounded numeric log + OperationFailed |
| 389 | child normalization | raw child status=103 | normalized status=40; bounded numeric log + OperationFailed |
| 390 | child normalization | raw child status=104 | normalized status=40; bounded numeric log + OperationFailed |
| 391 | child normalization | raw child status=105 | normalized status=40; bounded numeric log + OperationFailed |
| 392 | child normalization | raw child status=106 | normalized status=40; bounded numeric log + OperationFailed |
| 393 | child normalization | raw child status=107 | normalized status=40; bounded numeric log + OperationFailed |
| 394 | child normalization | raw child status=108 | normalized status=40; bounded numeric log + OperationFailed |
| 395 | child normalization | raw child status=109 | normalized status=40; bounded numeric log + OperationFailed |
| 396 | child normalization | raw child status=110 | normalized status=40; bounded numeric log + OperationFailed |
| 397 | child normalization | raw child status=111 | normalized status=40; bounded numeric log + OperationFailed |
| 398 | child normalization | raw child status=112 | normalized status=40; bounded numeric log + OperationFailed |
| 399 | child normalization | raw child status=113 | normalized status=40; bounded numeric log + OperationFailed |
| 400 | child normalization | raw child status=114 | normalized status=40; bounded numeric log + OperationFailed |
| 401 | child normalization | raw child status=115 | normalized status=40; bounded numeric log + OperationFailed |
| 402 | child normalization | raw child status=116 | normalized status=40; bounded numeric log + OperationFailed |
| 403 | child normalization | raw child status=117 | normalized status=40; bounded numeric log + OperationFailed |
| 404 | child normalization | raw child status=118 | normalized status=40; bounded numeric log + OperationFailed |
| 405 | child normalization | raw child status=119 | normalized status=40; bounded numeric log + OperationFailed |
| 406 | child normalization | raw child status=120 | normalized status=40; bounded numeric log + OperationFailed |
| 407 | child normalization | raw child status=121 | normalized status=40; bounded numeric log + OperationFailed |
| 408 | child normalization | raw child status=122 | normalized status=40; bounded numeric log + OperationFailed |
| 409 | child normalization | raw child status=123 | normalized status=40; bounded numeric log + OperationFailed |
| 410 | child normalization | raw child status=124 | normalized status=40; bounded numeric log + OperationFailed |
| 411 | child normalization | raw child status=125 | normalized status=40; bounded numeric log + OperationFailed |
| 412 | child normalization | raw child status=126 | normalized status=40; bounded numeric log + OperationFailed |
| 413 | child normalization | raw child status=127 | normalized status=40; bounded numeric log + OperationFailed |
| 414 | child normalization | raw child status=128 | normalized status=40; bounded numeric log + OperationFailed |
| 415 | child normalization | raw child status=129 | normalized status=40; bounded numeric log + OperationFailed |
| 416 | child normalization | raw child status=130 | normalized status=40; bounded numeric log + OperationFailed |
| 417 | child normalization | raw child status=131 | normalized status=40; bounded numeric log + OperationFailed |
| 418 | child normalization | raw child status=132 | normalized status=40; bounded numeric log + OperationFailed |
| 419 | child normalization | raw child status=133 | normalized status=40; bounded numeric log + OperationFailed |
| 420 | child normalization | raw child status=134 | normalized status=40; bounded numeric log + OperationFailed |
| 421 | child normalization | raw child status=135 | normalized status=40; bounded numeric log + OperationFailed |
| 422 | child normalization | raw child status=136 | normalized status=40; bounded numeric log + OperationFailed |
| 423 | child normalization | raw child status=137 | normalized status=40; bounded numeric log + OperationFailed |
| 424 | child normalization | raw child status=138 | normalized status=40; bounded numeric log + OperationFailed |
| 425 | child normalization | raw child status=139 | normalized status=40; bounded numeric log + OperationFailed |
| 426 | child normalization | raw child status=140 | normalized status=40; bounded numeric log + OperationFailed |
| 427 | child normalization | raw child status=141 | normalized status=40; bounded numeric log + OperationFailed |
| 428 | child normalization | raw child status=142 | normalized status=40; bounded numeric log + OperationFailed |
| 429 | child normalization | raw child status=143 | normalized status=40; bounded numeric log + OperationFailed |
| 430 | child normalization | raw child status=144 | normalized status=40; bounded numeric log + OperationFailed |
| 431 | child normalization | raw child status=145 | normalized status=40; bounded numeric log + OperationFailed |
| 432 | child normalization | raw child status=146 | normalized status=40; bounded numeric log + OperationFailed |
| 433 | child normalization | raw child status=147 | normalized status=40; bounded numeric log + OperationFailed |
| 434 | child normalization | raw child status=148 | normalized status=40; bounded numeric log + OperationFailed |
| 435 | child normalization | raw child status=149 | normalized status=40; bounded numeric log + OperationFailed |
| 436 | child normalization | raw child status=150 | normalized status=40; bounded numeric log + OperationFailed |
| 437 | child normalization | raw child status=151 | normalized status=40; bounded numeric log + OperationFailed |
| 438 | child normalization | raw child status=152 | normalized status=40; bounded numeric log + OperationFailed |
| 439 | child normalization | raw child status=153 | normalized status=40; bounded numeric log + OperationFailed |
| 440 | child normalization | raw child status=154 | normalized status=40; bounded numeric log + OperationFailed |
| 441 | child normalization | raw child status=155 | normalized status=40; bounded numeric log + OperationFailed |
| 442 | child normalization | raw child status=156 | normalized status=40; bounded numeric log + OperationFailed |
| 443 | child normalization | raw child status=157 | normalized status=40; bounded numeric log + OperationFailed |
| 444 | child normalization | raw child status=158 | normalized status=40; bounded numeric log + OperationFailed |
| 445 | child normalization | raw child status=159 | normalized status=40; bounded numeric log + OperationFailed |
| 446 | child normalization | raw child status=160 | normalized status=40; bounded numeric log + OperationFailed |
| 447 | child normalization | raw child status=161 | normalized status=40; bounded numeric log + OperationFailed |
| 448 | child normalization | raw child status=162 | normalized status=40; bounded numeric log + OperationFailed |
| 449 | child normalization | raw child status=163 | normalized status=40; bounded numeric log + OperationFailed |
| 450 | child normalization | raw child status=164 | normalized status=40; bounded numeric log + OperationFailed |
| 451 | child normalization | raw child status=165 | normalized status=40; bounded numeric log + OperationFailed |
| 452 | child normalization | raw child status=166 | normalized status=40; bounded numeric log + OperationFailed |
| 453 | child normalization | raw child status=167 | normalized status=40; bounded numeric log + OperationFailed |
| 454 | child normalization | raw child status=168 | normalized status=40; bounded numeric log + OperationFailed |
| 455 | child normalization | raw child status=169 | normalized status=40; bounded numeric log + OperationFailed |
| 456 | child normalization | raw child status=170 | normalized status=40; bounded numeric log + OperationFailed |
| 457 | child normalization | raw child status=171 | normalized status=40; bounded numeric log + OperationFailed |
| 458 | child normalization | raw child status=172 | normalized status=40; bounded numeric log + OperationFailed |
| 459 | child normalization | raw child status=173 | normalized status=40; bounded numeric log + OperationFailed |
| 460 | child normalization | raw child status=174 | normalized status=40; bounded numeric log + OperationFailed |
| 461 | child normalization | raw child status=175 | normalized status=40; bounded numeric log + OperationFailed |
| 462 | child normalization | raw child status=176 | normalized status=40; bounded numeric log + OperationFailed |
| 463 | child normalization | raw child status=177 | normalized status=40; bounded numeric log + OperationFailed |
| 464 | child normalization | raw child status=178 | normalized status=40; bounded numeric log + OperationFailed |
| 465 | child normalization | raw child status=179 | normalized status=40; bounded numeric log + OperationFailed |
| 466 | child normalization | raw child status=180 | normalized status=40; bounded numeric log + OperationFailed |
| 467 | child normalization | raw child status=181 | normalized status=40; bounded numeric log + OperationFailed |
| 468 | child normalization | raw child status=182 | normalized status=40; bounded numeric log + OperationFailed |
| 469 | child normalization | raw child status=183 | normalized status=40; bounded numeric log + OperationFailed |
| 470 | child normalization | raw child status=184 | normalized status=40; bounded numeric log + OperationFailed |
| 471 | child normalization | raw child status=185 | normalized status=40; bounded numeric log + OperationFailed |
| 472 | child normalization | raw child status=186 | normalized status=40; bounded numeric log + OperationFailed |
| 473 | child normalization | raw child status=187 | normalized status=40; bounded numeric log + OperationFailed |
| 474 | child normalization | raw child status=188 | normalized status=40; bounded numeric log + OperationFailed |
| 475 | child normalization | raw child status=189 | normalized status=40; bounded numeric log + OperationFailed |
| 476 | child normalization | raw child status=190 | normalized status=40; bounded numeric log + OperationFailed |
| 477 | child normalization | raw child status=191 | normalized status=40; bounded numeric log + OperationFailed |
| 478 | child normalization | raw child status=192 | normalized status=40; bounded numeric log + OperationFailed |
| 479 | child normalization | raw child status=193 | normalized status=40; bounded numeric log + OperationFailed |
| 480 | child normalization | raw child status=194 | normalized status=40; bounded numeric log + OperationFailed |
| 481 | child normalization | raw child status=195 | normalized status=40; bounded numeric log + OperationFailed |
| 482 | child normalization | raw child status=196 | normalized status=40; bounded numeric log + OperationFailed |
| 483 | child normalization | raw child status=197 | normalized status=40; bounded numeric log + OperationFailed |
| 484 | child normalization | raw child status=198 | normalized status=40; bounded numeric log + OperationFailed |
| 485 | child normalization | raw child status=199 | normalized status=40; bounded numeric log + OperationFailed |
| 486 | child normalization | raw child status=200 | normalized status=40; bounded numeric log + OperationFailed |
| 487 | child normalization | raw child status=201 | normalized status=40; bounded numeric log + OperationFailed |
| 488 | child normalization | raw child status=202 | normalized status=40; bounded numeric log + OperationFailed |
| 489 | child normalization | raw child status=203 | normalized status=40; bounded numeric log + OperationFailed |
| 490 | child normalization | raw child status=204 | normalized status=40; bounded numeric log + OperationFailed |
| 491 | child normalization | raw child status=205 | normalized status=40; bounded numeric log + OperationFailed |
| 492 | child normalization | raw child status=206 | normalized status=40; bounded numeric log + OperationFailed |
| 493 | child normalization | raw child status=207 | normalized status=40; bounded numeric log + OperationFailed |
| 494 | child normalization | raw child status=208 | normalized status=40; bounded numeric log + OperationFailed |
| 495 | child normalization | raw child status=209 | normalized status=40; bounded numeric log + OperationFailed |
| 496 | child normalization | raw child status=210 | normalized status=40; bounded numeric log + OperationFailed |
| 497 | child normalization | raw child status=211 | normalized status=40; bounded numeric log + OperationFailed |
| 498 | child normalization | raw child status=212 | normalized status=40; bounded numeric log + OperationFailed |
| 499 | child normalization | raw child status=213 | normalized status=40; bounded numeric log + OperationFailed |
| 500 | child normalization | raw child status=214 | normalized status=40; bounded numeric log + OperationFailed |
| 501 | child normalization | raw child status=215 | normalized status=40; bounded numeric log + OperationFailed |
| 502 | child normalization | raw child status=216 | normalized status=40; bounded numeric log + OperationFailed |
| 503 | child normalization | raw child status=217 | normalized status=40; bounded numeric log + OperationFailed |
| 504 | child normalization | raw child status=218 | normalized status=40; bounded numeric log + OperationFailed |
| 505 | child normalization | raw child status=219 | normalized status=40; bounded numeric log + OperationFailed |
| 506 | child normalization | raw child status=220 | normalized status=40; bounded numeric log + OperationFailed |
| 507 | child normalization | raw child status=221 | normalized status=40; bounded numeric log + OperationFailed |
| 508 | child normalization | raw child status=222 | normalized status=40; bounded numeric log + OperationFailed |
| 509 | child normalization | raw child status=223 | normalized status=40; bounded numeric log + OperationFailed |
| 510 | child normalization | raw child status=224 | normalized status=40; bounded numeric log + OperationFailed |
| 511 | child normalization | raw child status=225 | normalized status=40; bounded numeric log + OperationFailed |
| 512 | child normalization | raw child status=226 | normalized status=40; bounded numeric log + OperationFailed |
| 513 | child normalization | raw child status=227 | normalized status=40; bounded numeric log + OperationFailed |
| 514 | child normalization | raw child status=228 | normalized status=40; bounded numeric log + OperationFailed |
| 515 | child normalization | raw child status=229 | normalized status=40; bounded numeric log + OperationFailed |
| 516 | child normalization | raw child status=230 | normalized status=40; bounded numeric log + OperationFailed |
| 517 | child normalization | raw child status=231 | normalized status=40; bounded numeric log + OperationFailed |
| 518 | child normalization | raw child status=232 | normalized status=40; bounded numeric log + OperationFailed |
| 519 | child normalization | raw child status=233 | normalized status=40; bounded numeric log + OperationFailed |
| 520 | child normalization | raw child status=234 | normalized status=40; bounded numeric log + OperationFailed |
| 521 | child normalization | raw child status=235 | normalized status=40; bounded numeric log + OperationFailed |
| 522 | child normalization | raw child status=236 | normalized status=40; bounded numeric log + OperationFailed |
| 523 | child normalization | raw child status=237 | normalized status=40; bounded numeric log + OperationFailed |
| 524 | child normalization | raw child status=238 | normalized status=40; bounded numeric log + OperationFailed |
| 525 | child normalization | raw child status=239 | normalized status=40; bounded numeric log + OperationFailed |
| 526 | child normalization | raw child status=240 | normalized status=40; bounded numeric log + OperationFailed |
| 527 | child normalization | raw child status=241 | normalized status=40; bounded numeric log + OperationFailed |
| 528 | child normalization | raw child status=242 | normalized status=40; bounded numeric log + OperationFailed |
| 529 | child normalization | raw child status=243 | normalized status=40; bounded numeric log + OperationFailed |
| 530 | child normalization | raw child status=244 | normalized status=40; bounded numeric log + OperationFailed |
| 531 | child normalization | raw child status=245 | normalized status=40; bounded numeric log + OperationFailed |
| 532 | child normalization | raw child status=246 | normalized status=40; bounded numeric log + OperationFailed |
| 533 | child normalization | raw child status=247 | normalized status=40; bounded numeric log + OperationFailed |
| 534 | child normalization | raw child status=248 | normalized status=40; bounded numeric log + OperationFailed |
| 535 | child normalization | raw child status=249 | normalized status=40; bounded numeric log + OperationFailed |
| 536 | child normalization | raw child status=250 | normalized status=40; bounded numeric log + OperationFailed |
| 537 | child normalization | raw child status=251 | normalized status=40; bounded numeric log + OperationFailed |
| 538 | child normalization | raw child status=252 | normalized status=40; bounded numeric log + OperationFailed |
| 539 | child normalization | raw child status=253 | normalized status=40; bounded numeric log + OperationFailed |
| 540 | child normalization | raw child status=254 | normalized status=40; bounded numeric log + OperationFailed |
| 541 | child normalization | raw child status=255 | normalized status=40; bounded numeric log + OperationFailed |
| 542 | freeze/boundary | TASK-4.1 result header byte identity | protected or explicitly out of scope |
| 543 | freeze/boundary | TASK-4.1 result implementation byte identity | protected or explicitly out of scope |
| 544 | freeze/boundary | schemaVersion remains 1 | protected or explicitly out of scope |
| 545 | freeze/boundary | root keys remain 10 | protected or explicitly out of scope |
| 546 | freeze/boundary | fatalError keys remain 3 | protected or explicitly out of scope |
| 547 | freeze/boundary | binary-plist/base64 framing unchanged | protected or explicitly out of scope |
| 548 | freeze/boundary | output prefix unchanged | protected or explicitly out of scope |
| 549 | freeze/boundary | privacy exclusions unchanged | protected or explicitly out of scope |
| 550 | freeze/boundary | fixed bounds unchanged | protected or explicitly out of scope |
| 551 | freeze/boundary | KeychainBackupHelper header byte identity | protected or explicitly out of scope |
| 552 | freeze/boundary | KeychainBackupHelper implementation byte identity | protected or explicitly out of scope |
| 553 | freeze/boundary | SecItemCopyMatching call sites unchanged | protected or explicitly out of scope |
| 554 | freeze/boundary | SecItemAdd call sites unchanged | protected or explicitly out of scope |
| 555 | freeze/boundary | SecItemDelete call sites unchanged | protected or explicitly out of scope |
| 556 | freeze/boundary | broad restore pre-wipe unchanged | protected or explicitly out of scope |
| 557 | freeze/boundary | backup file schema unchanged | protected or explicitly out of scope |
| 558 | freeze/boundary | item count semantics unchanged | protected or explicitly out of scope |
| 559 | freeze/boundary | warning/error semantics unchanged | protected or explicitly out of scope |
| 560 | freeze/boundary | AppDataBackupManager byte identity | protected or explicitly out of scope |
| 561 | freeze/boundary | AppDataCleaner byte identity | protected or explicitly out of scope |
| 562 | freeze/boundary | WeaponXKeychainBridge byte identity | protected or explicitly out of scope |
| 563 | freeze/boundary | manager remains zero/nonzero only | protected or explicitly out of scope |
| 564 | freeze/boundary | cleaner remains zero/nonzero only | protected or explicitly out of scope |
| 565 | freeze/boundary | Partial 10 fails closed in manager | protected or explicitly out of scope |
| 566 | freeze/boundary | Partial 10 fails closed in cleaner | protected or explicitly out of scope |
| 567 | freeze/boundary | Restore warning-only aggregate policy unchanged | protected or explicitly out of scope |
| 568 | freeze/boundary | Clear failure accounting unchanged | protected or explicitly out of scope |
| 569 | freeze/boundary | no result parser added | protected or explicitly out of scope |
| 570 | freeze/boundary | no exact-code caller switch added | protected or explicitly out of scope |
| 571 | freeze/boundary | TASK-4.3 not implemented | protected or explicitly out of scope |
| 572 | freeze/boundary | TASK-4.4 not implemented | protected or explicitly out of scope |
| 573 | freeze/boundary | TASK-4.5 not implemented | protected or explicitly out of scope |
| 574 | freeze/boundary | TASK-4.6 not implemented | protected or explicitly out of scope |
| 575 | freeze/boundary | TASK-4.7 not implemented | protected or explicitly out of scope |
| 576 | freeze/boundary | TASK-4.8 not implemented | protected or explicitly out of scope |
| 577 | freeze/boundary | TASK-4.9 not implemented | protected or explicitly out of scope |
| 578 | freeze/boundary | bridge unification not implemented | protected or explicitly out of scope |
| 579 | freeze/boundary | rollback not implemented | protected or explicitly out of scope |
| 580 | freeze/boundary | UI/manifest/later phases not implemented | protected or explicitly out of scope |

## Protected SHA-256 and byte size before/after
The protected workspace bytes were present at the mandatory baseline and were never opened for write by TASK-4.2. Git confirms no protected path differs from the baseline tree; current SHA-256/size recapture matches the before snapshot for every row.

| File | Before SHA-256 | Before bytes | After SHA-256 | After bytes | Match |
|---|---|---:|---|---:|---:|
| `AppDataBackupManager.h` | `b19c1c61e6df642468d713dede5a0c0bd0dbb6a0ac72d98ad6878d3cae1f2e75` | 1442 | `b19c1c61e6df642468d713dede5a0c0bd0dbb6a0ac72d98ad6878d3cae1f2e75` | 1442 | TRUE |
| `AppDataBackupManager.m` | `d6a302c90ab988a2c9b27c36fa664bc219082c6175f631942426b5fb91d2191e` | 221835 | `d6a302c90ab988a2c9b27c36fa664bc219082c6175f631942426b5fb91d2191e` | 221835 | TRUE |
| `AppDataCleaner.h` | `b32a62280c2df60a33658e7ec9193b76802d989c984c42193f045a94365c915e` | 4768 | `b32a62280c2df60a33658e7ec9193b76802d989c984c42193f045a94365c915e` | 4768 | TRUE |
| `AppDataCleaner.m` | `69549666233bbbd812f16ba5abae9bfa875e5d85723a2a8f82d63b54332d4c93` | 370484 | `69549666233bbbd812f16ba5abae9bfa875e5d85723a2a8f82d63b54332d4c93` | 370484 | TRUE |
| `AppGroupContainerResolver.h` | `c18f6e6dd09d19dd49564d442c956eb3be4a153118faff392cdd899846263c97` | 1356 | `c18f6e6dd09d19dd49564d442c956eb3be4a153118faff392cdd899846263c97` | 1356 | TRUE |
| `AppGroupContainerResolver.m` | `11646d96beec86f070ea49e0a803fb1bc669bc48af56135f1acd7c39a5439df1` | 11499 | `11646d96beec86f070ea49e0a803fb1bc669bc48af56135f1acd7c39a5439df1` | 11499 | TRUE |
| `BackupKeychainGroupsViewController.h` | `fc77d536ab2a573b598ac7ff72339a63229d68f15ae239b827cb4dd2a78c2377` | 159 | `fc77d536ab2a573b598ac7ff72339a63229d68f15ae239b827cb4dd2a78c2377` | 159 | TRUE |
| `BackupKeychainGroupsViewController.m` | `2f0590d7b51b05733f92c9df19c93953c2ab14fc8ca7380c43b4126ea60c4ccf` | 9567 | `2f0590d7b51b05733f92c9df19c93953c2ab14fc8ca7380c43b4126ea60c4ccf` | 9567 | TRUE |
| `KeychainGroupsViewController.h` | `48945d11fbf9ee4e9921140fc7d674abacbed3076db2b514fc641b6ac118a50b` | 153 | `48945d11fbf9ee4e9921140fc7d674abacbed3076db2b514fc641b6ac118a50b` | 153 | TRUE |
| `KeychainGroupsViewController.m` | `0e25b51199550964a5f743e50dc49641d161efd347973d49f58cc861a6260d35` | 10227 | `0e25b51199550964a5f743e50dc49641d161efd347973d49f58cc861a6260d35` | 10227 | TRUE |
| `KeychainHelper/KeychainBackupHelper.h` | `dbf0d5a4bdfc1df3e4f74b103968e018d0932f89c245bae8f260b196c0664281` | 4280 | `dbf0d5a4bdfc1df3e4f74b103968e018d0932f89c245bae8f260b196c0664281` | 4280 | TRUE |
| `KeychainHelper/KeychainBackupHelper.m` | `203884bf8d009a01a936acb5371c9316f7a0d6212b0d226f7f8a7661d51d122c` | 27970 | `203884bf8d009a01a936acb5371c9316f7a0d6212b0d226f7f8a7661d51d122c` | 27970 | TRUE |
| `KeychainHelper/PXKeychainHelperResult.h` | `96c326226fbb22e7b69dc68f4088aa5e6c171d391ad0bca8d321318f041f9d14` | 3191 | `96c326226fbb22e7b69dc68f4088aa5e6c171d391ad0bca8d321318f041f9d14` | 3191 | TRUE |
| `KeychainHelper/PXKeychainHelperResult.m` | `2ff85dd7bc0e3af97b0fdf2ccd00072d6ba2d324ef70e4c4e26b739d745d9035` | 27477 | `2ff85dd7bc0e3af97b0fdf2ccd00072d6ba2d324ef70e4c4e26b739d745d9035` | 27477 | TRUE |
| `Makefile` | `9ed7ed6b376c96b8a3df8d9e169670476feabee186a177f9fe09118265a6d8c0` | 9186 | `9ed7ed6b376c96b8a3df8d9e169670476feabee186a177f9fe09118265a6d8c0` | 9186 | TRUE |
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

## Authorized source before/after
| File | Before SHA-256 | Before bytes | After SHA-256 | After bytes |
|---|---|---:|---|---:|
| `KeychainHelper/PXKeychainHelperExitCode.h` | ABSENT | 0 | `a0682225ac3ff962305c5bd967f319a4ad0aa7f5eec0a98596e04ba78b21e99a` | 784 |
| `KeychainHelper/backup_helper.m` | `0f68c2eef016ea098d7f83a10e2016693caefa994fab58e5a5801b02c8ebaecf` | 24800 | `cdd75a01da5ae7f6cdb1096724b146a54b4e1cb9096e3a077152458530c4fb0f` | 28224 |
| `scripts/keychain_backup.sh` | `b3f05517ab230b9f37acfefe4c81568e3f88268c5e110653a50b3d30bd9437ae` | 32096 | `1ea608e75ed03ab92eb2bb1ab15a68a721a9a9b80c52c3d0b1229b3b96bc2c26` | 36263 |
| `docs/backup-restore-hardening/reports/TASK-4.2-REPORT.md` | ABSENT | 0 | SELF-REFERENTIAL | SELF-REFERENTIAL |

## Authorized full production diff
The report excludes its own diff/hash to avoid recursive self-embedding. Blank diff context marker lines are whitespace-normalized only.
```diff
diff --git a/KeychainHelper/PXKeychainHelperExitCode.h b/KeychainHelper/PXKeychainHelperExitCode.h
new file mode 100644
index 0000000..bef59a1
--- /dev/null
+++ b/KeychainHelper/PXKeychainHelperExitCode.h
@@ -0,0 +1,21 @@
+#import <Foundation/Foundation.h>
+
+NS_ASSUME_NONNULL_BEGIN
+
+typedef NS_ENUM(NSInteger, PXKeychainHelperExitCode) {
+    PXKeychainHelperExitCodeCompleted = 0,
+    PXKeychainHelperExitCodePartial = 10,
+    PXKeychainHelperExitCodeInvalidArguments = 20,
+    PXKeychainHelperExitCodeInvalidInput = 21,
+    PXKeychainHelperExitCodeAccessDenied = 30,
+    PXKeychainHelperExitCodeOperationFailed = 40,
+    PXKeychainHelperExitCodeProtocolFailure = 50,
+    PXKeychainHelperExitCodeHelperUnavailable = 60,
+    PXKeychainHelperExitCodeTargetUnavailable = 61,
+    PXKeychainHelperExitCodeEntitlementFailure = 62,
+    PXKeychainHelperExitCodeWorkspaceFailure = 63,
+    PXKeychainHelperExitCodeSigningFailure = 64,
+    PXKeychainHelperExitCodeDependencyUnavailable = 65,
+};
+
+NS_ASSUME_NONNULL_END
diff --git a/KeychainHelper/backup_helper.m b/KeychainHelper/backup_helper.m
index d050485..ff06f7d 100644
--- a/KeychainHelper/backup_helper.m
+++ b/KeychainHelper/backup_helper.m
@@ -11,14 +11,18 @@
  * entitlements before running. Use the keychain_backup.sh wrapper script.
  *
  * Exit codes:
- *   0 - Success
- *   1 - Invalid arguments
- *   2 - Operation failed
- *   3 - Access denied (missing entitlements)
+ *   0  - Completed
+ *   10 - Partial
+ *   20 - Invalid arguments
+ *   21 - Invalid input
+ *   30 - Access denied
+ *   40 - Operation failed
+ *   50 - Structured-result protocol failure
  */

 #import <Foundation/Foundation.h>
 #import "KeychainBackupHelper.h"
+#import "PXKeychainHelperExitCode.h"
 #import "PXKeychainHelperResult.h"

 typedef NS_ENUM(NSInteger, PXHelperAction) {
@@ -151,6 +155,29 @@ static NSError *PXStructuredSyntheticError(PXKeychainBackupErrorCode code) {
     return [NSError errorWithDomain:PXKeychainBackupErrorDomain code:code userInfo:nil];
 }

+static PXKeychainHelperExitCode PXExitCodeForFatalError(PXKeychainHelperOperation operation,
+                                                         NSError *fatalError) {
+    if (![fatalError.domain isEqualToString:PXKeychainBackupErrorDomain]) {
+        return PXKeychainHelperExitCodeOperationFailed;
+    }
+
+    switch ((PXKeychainBackupErrorCode)fatalError.code) {
+        case PXKeychainBackupErrorInvalidArguments:
+        case PXKeychainBackupErrorNoAccessGroups:
+            return PXKeychainHelperExitCodeInvalidArguments;
+        case PXKeychainBackupErrorSecurityFramework:
+            return PXKeychainHelperExitCodeAccessDenied;
+        case PXKeychainBackupErrorFileIO:
+        case PXKeychainBackupErrorInvalidBackupFile:
+            return operation == PXKeychainHelperOperationRestore
+                ? PXKeychainHelperExitCodeInvalidInput
+                : PXKeychainHelperExitCodeOperationFailed;
+        case PXKeychainBackupErrorUnknown:
+            return PXKeychainHelperExitCodeOperationFailed;
+    }
+    return PXKeychainHelperExitCodeOperationFailed;
+}
+
 static PXKeychainHelperResult *PXCreateStructuredResult(PXKeychainHelperOperation operation,
                                                         PXKeychainHelperCompletion completion,
                                                         PXKeychainBackupResult *result,
@@ -198,6 +225,39 @@ static void PXEmitStructuredResult(PXKeychainHelperResult *result) {
     fflush(stdout);
 }

+static PXKeychainHelperExitCode PXFinalizeStructuredResult(
+    PXKeychainHelperResult *result,
+    PXKeychainHelperExitCode intendedExitCode) {
+    NSString *line = result.machineReadableLine;
+    BOOL compatible = result != nil &&
+                      line.length > PXKeychainHelperResultOutputPrefix.length &&
+                      [line hasPrefix:PXKeychainHelperResultOutputPrefix] &&
+                      [line rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet]].location == NSNotFound;
+
+    if (compatible) {
+        switch (result.completion) {
+            case PXKeychainHelperCompletionCompleted:
+                compatible = intendedExitCode == PXKeychainHelperExitCodeCompleted;
+                break;
+            case PXKeychainHelperCompletionPartial:
+                compatible = intendedExitCode == PXKeychainHelperExitCodePartial;
+                break;
+            case PXKeychainHelperCompletionFailed:
+                compatible = intendedExitCode == PXKeychainHelperExitCodeInvalidArguments ||
+                             intendedExitCode == PXKeychainHelperExitCodeInvalidInput ||
+                             intendedExitCode == PXKeychainHelperExitCodeAccessDenied ||
+                             intendedExitCode == PXKeychainHelperExitCodeOperationFailed;
+                break;
+            default:
+                compatible = NO;
+                break;
+        }
+    }
+
+    PXEmitStructuredResult(compatible ? result : nil);
+    return compatible ? intendedExitCode : PXKeychainHelperExitCodeProtocolFailure;
+}
+
 int main(int argc, const char *argv[]) {
     @autoreleasepool {
         // Parse arguments.
@@ -208,7 +268,7 @@ int main(int argc, const char *argv[]) {

             if ([arg isEqualToString:@"--help"] || [arg isEqualToString:@"-h"]) {
                 printUsage(argv[0]);
-                return 0;
+                return PXKeychainHelperExitCodeCompleted;
             } else if ([arg isEqualToString:@"--verbose"] || [arg isEqualToString:@"-v"]) {
                 args[@"verbose"] = @YES;
             } else if ([arg isEqualToString:@"--overwrite"]) {
@@ -227,24 +287,26 @@ int main(int argc, const char *argv[]) {
         if (!actionStr.length) {
             logError(@"Missing required --action argument");
             printUsage(argv[0]);
-            PXEmitStructuredResult(PXCreateStructuredResult(PXKeychainHelperOperationUnknown,
-                                                            PXKeychainHelperCompletionFailed,
-                                                            nil,
-                                                            0,
-                                                            PXStructuredSyntheticError(PXKeychainBackupErrorInvalidArguments)));
-            return 1;
+            return PXFinalizeStructuredResult(
+                PXCreateStructuredResult(PXKeychainHelperOperationUnknown,
+                                         PXKeychainHelperCompletionFailed,
+                                         nil,
+                                         0,
+                                         PXStructuredSyntheticError(PXKeychainBackupErrorInvalidArguments)),
+                PXKeychainHelperExitCodeInvalidArguments);
         }

         PXHelperAction action = parseAction(actionStr);
         if (action == PXHelperActionUnknown) {
             logError(@"Unknown action: %@", actionStr);
             printUsage(argv[0]);
-            PXEmitStructuredResult(PXCreateStructuredResult(PXKeychainHelperOperationUnknown,
-                                                            PXKeychainHelperCompletionFailed,
-                                                            nil,
-                                                            0,
-                                                            PXStructuredSyntheticError(PXKeychainBackupErrorInvalidArguments)));
-            return 1;
+            return PXFinalizeStructuredResult(
+                PXCreateStructuredResult(PXKeychainHelperOperationUnknown,
+                                         PXKeychainHelperCompletionFailed,
+                                         nil,
+                                         0,
+                                         PXStructuredSyntheticError(PXKeychainBackupErrorInvalidArguments)),
+                PXKeychainHelperExitCodeInvalidArguments);
         }
         PXKeychainHelperOperation structuredOperation = PXStructuredOperationForAction(action);

@@ -263,21 +325,23 @@ int main(int argc, const char *argv[]) {
             case PXHelperActionBackup: {
                 if (!filePath.length) {
                     logError(@"--file is required for backup");
-                    PXEmitStructuredResult(PXCreateStructuredResult(structuredOperation,
-                                                                    PXKeychainHelperCompletionFailed,
-                                                                    nil,
-                                                                    0,
-                                                                    PXStructuredSyntheticError(PXKeychainBackupErrorInvalidArguments)));
-                    return 1;
+                    return PXFinalizeStructuredResult(
+                        PXCreateStructuredResult(structuredOperation,
+                                                 PXKeychainHelperCompletionFailed,
+                                                 nil,
+                                                 0,
+                                                 PXStructuredSyntheticError(PXKeychainBackupErrorInvalidArguments)),
+                        PXKeychainHelperExitCodeInvalidArguments);
                 }
                 if (!groups.count) {
                     logError(@"--groups is required for backup");
-                    PXEmitStructuredResult(PXCreateStructuredResult(structuredOperation,
-                                                                    PXKeychainHelperCompletionFailed,
-                                                                    nil,
-                                                                    0,
-                                                                    PXStructuredSyntheticError(PXKeychainBackupErrorNoAccessGroups)));
-                    return 1;
+                    return PXFinalizeStructuredResult(
+                        PXCreateStructuredResult(structuredOperation,
+                                                 PXKeychainHelperCompletionFailed,
+                                                 nil,
+                                                 0,
+                                                 PXStructuredSyntheticError(PXKeychainBackupErrorNoAccessGroups)),
+                        PXKeychainHelperExitCodeInvalidArguments);
                 }

                 logVerbose(verbose, @"Starting keychain backup...");
@@ -288,12 +352,16 @@ int main(int argc, const char *argv[]) {

                 if (!result) {
                     logError(@"Backup failed: %@", error.localizedDescription);
-                    PXEmitStructuredResult(PXCreateStructuredResult(structuredOperation,
-                                                                    PXKeychainHelperCompletionFailed,
-                                                                    nil,
-                                                                    0,
-                                                                    error ?: PXStructuredSyntheticError(PXKeychainBackupErrorUnknown)));
-                    return 2;
+                    NSError *fatalError = error ?: PXStructuredSyntheticError(PXKeychainBackupErrorUnknown);
+                    PXKeychainHelperExitCode exitCode =
+                        PXExitCodeForFatalError(structuredOperation, fatalError);
+                    return PXFinalizeStructuredResult(
+                        PXCreateStructuredResult(structuredOperation,
+                                                 PXKeychainHelperCompletionFailed,
+                                                 nil,
+                                                 0,
+                                                 fatalError),
+                        exitCode);
                 }

                 logSuccess(@"Backup complete: %lu items processed, %lu succeeded, %lu failed",
@@ -305,23 +373,25 @@ int main(int argc, const char *argv[]) {
                     NSString *warning = PXSafeString(warningObj);
                     fprintf(stderr, "[WARN] %s\n", [warning UTF8String] ?: "");
                 }
-                PXEmitStructuredResult(PXCreateStructuredResult(structuredOperation,
-                                                                PXStructuredCompletionForResult(result),
-                                                                result,
-                                                                0,
-                                                                nil));
-                return 0;
+                PXKeychainHelperCompletion completion = PXStructuredCompletionForResult(result);
+                PXKeychainHelperExitCode exitCode = completion == PXKeychainHelperCompletionCompleted
+                    ? PXKeychainHelperExitCodeCompleted
+                    : PXKeychainHelperExitCodePartial;
+                return PXFinalizeStructuredResult(
+                    PXCreateStructuredResult(structuredOperation, completion, result, 0, nil),
+                    exitCode);
             }

             case PXHelperActionRestore: {
                 if (!filePath.length) {
                     logError(@"--file is required for restore");
-                    PXEmitStructuredResult(PXCreateStructuredResult(structuredOperation,
-                                                                    PXKeychainHelperCompletionFailed,
-                                                                    nil,
-                                                                    0,
-                                                                    PXStructuredSyntheticError(PXKeychainBackupErrorInvalidArguments)));
-                    return 1;
+                    return PXFinalizeStructuredResult(
+                        PXCreateStructuredResult(structuredOperation,
+                                                 PXKeychainHelperCompletionFailed,
+                                                 nil,
+                                                 0,
+                                                 PXStructuredSyntheticError(PXKeychainBackupErrorInvalidArguments)),
+                        PXKeychainHelperExitCodeInvalidArguments);
                 }

                 logVerbose(verbose, @"Starting keychain restore (overwrite: %@)...",
@@ -332,12 +402,16 @@ int main(int argc, const char *argv[]) {

                 if (!result) {
                     logError(@"Restore failed: %@", error.localizedDescription);
-                    PXEmitStructuredResult(PXCreateStructuredResult(structuredOperation,
-                                                                    PXKeychainHelperCompletionFailed,
-                                                                    nil,
-                                                                    0,
-                                                                    error ?: PXStructuredSyntheticError(PXKeychainBackupErrorUnknown)));
-                    return 2;
+                    NSError *fatalError = error ?: PXStructuredSyntheticError(PXKeychainBackupErrorUnknown);
+                    PXKeychainHelperExitCode exitCode =
+                        PXExitCodeForFatalError(structuredOperation, fatalError);
+                    return PXFinalizeStructuredResult(
+                        PXCreateStructuredResult(structuredOperation,
+                                                 PXKeychainHelperCompletionFailed,
+                                                 nil,
+                                                 0,
+                                                 fatalError),
+                        exitCode);
                 }

                 logSuccess(@"Restore complete: %lu items processed, %lu succeeded, %lu failed",
@@ -353,23 +427,25 @@ int main(int argc, const char *argv[]) {
                     NSString *err = PXSafeString(errObj);
                     fprintf(stderr, "[ERR] %s\n", [err UTF8String] ?: "");
                 }
-                PXEmitStructuredResult(PXCreateStructuredResult(structuredOperation,
-                                                                PXStructuredCompletionForResult(result),
-                                                                result,
-                                                                0,
-                                                                nil));
-                return 0;
+                PXKeychainHelperCompletion completion = PXStructuredCompletionForResult(result);
+                PXKeychainHelperExitCode exitCode = completion == PXKeychainHelperCompletionCompleted
+                    ? PXKeychainHelperExitCodeCompleted
+                    : PXKeychainHelperExitCodePartial;
+                return PXFinalizeStructuredResult(
+                    PXCreateStructuredResult(structuredOperation, completion, result, 0, nil),
+                    exitCode);
             }

             case PXHelperActionWipe: {
                 if (!groups.count) {
                     logError(@"--groups is required for wipe");
-                    PXEmitStructuredResult(PXCreateStructuredResult(structuredOperation,
-                                                                    PXKeychainHelperCompletionFailed,
-                                                                    nil,
-                                                                    0,
-                                                                    PXStructuredSyntheticError(PXKeychainBackupErrorNoAccessGroups)));
-                    return 1;
+                    return PXFinalizeStructuredResult(
+                        PXCreateStructuredResult(structuredOperation,
+                                                 PXKeychainHelperCompletionFailed,
+                                                 nil,
+                                                 0,
+                                                 PXStructuredSyntheticError(PXKeychainBackupErrorNoAccessGroups)),
+                        PXKeychainHelperExitCodeInvalidArguments);
                 }

                 logVerbose(verbose, @"Starting keychain wipe...");
@@ -390,12 +466,16 @@ int main(int argc, const char *argv[]) {

                 if (!result) {
                     logError(@"Wipe failed: %@", error.localizedDescription);
-                    PXEmitStructuredResult(PXCreateStructuredResult(structuredOperation,
-                                                                    PXKeychainHelperCompletionFailed,
-                                                                    nil,
-                                                                    0,
-                                                                    error ?: PXStructuredSyntheticError(PXKeychainBackupErrorUnknown)));
-                    return 2;
+                    NSError *fatalError = error ?: PXStructuredSyntheticError(PXKeychainBackupErrorUnknown);
+                    PXKeychainHelperExitCode exitCode =
+                        PXExitCodeForFatalError(structuredOperation, fatalError);
+                    return PXFinalizeStructuredResult(
+                        PXCreateStructuredResult(structuredOperation,
+                                                 PXKeychainHelperCompletionFailed,
+                                                 nil,
+                                                 0,
+                                                 fatalError),
+                        exitCode);
                 }

                 for (id warningObj in result.warnings) {
@@ -403,33 +483,36 @@ int main(int argc, const char *argv[]) {
                     fprintf(stderr, "[WARN] %s\n", [warning UTF8String] ?: "");
                 }
                 if (result.itemsFailed > 0 || result.warnings.count > 0) {
-                    PXEmitStructuredResult(PXCreateStructuredResult(structuredOperation,
-                                                                    PXStructuredCompletionForResult(result),
-                                                                    result,
-                                                                    0,
-                                                                    nil));
-                    return 2;
+                    return PXFinalizeStructuredResult(
+                        PXCreateStructuredResult(structuredOperation,
+                                                 PXKeychainHelperCompletionPartial,
+                                                 result,
+                                                 0,
+                                                 nil),
+                        PXKeychainHelperExitCodePartial);
                 }

                 logSuccess(@"Wipe complete: %lu items deleted",
                           (unsigned long)result.itemsSucceeded);
-                PXEmitStructuredResult(PXCreateStructuredResult(structuredOperation,
-                                                                PXStructuredCompletionForResult(result),
-                                                                result,
-                                                                0,
-                                                                nil));
-                return 0;
+                PXKeychainHelperCompletion completion = PXStructuredCompletionForResult(result);
+                PXKeychainHelperExitCode exitCode = completion == PXKeychainHelperCompletionCompleted
+                    ? PXKeychainHelperExitCodeCompleted
+                    : PXKeychainHelperExitCodePartial;
+                return PXFinalizeStructuredResult(
+                    PXCreateStructuredResult(structuredOperation, completion, result, 0, nil),
+                    exitCode);
             }

             case PXHelperActionList: {
                 if (!groups.count) {
                     logError(@"--groups is required for list");
-                    PXEmitStructuredResult(PXCreateStructuredResult(structuredOperation,
-                                                                    PXKeychainHelperCompletionFailed,
-                                                                    nil,
-                                                                    0,
-                                                                    PXStructuredSyntheticError(PXKeychainBackupErrorNoAccessGroups)));
-                    return 1;
+                    return PXFinalizeStructuredResult(
+                        PXCreateStructuredResult(structuredOperation,
+                                                 PXKeychainHelperCompletionFailed,
+                                                 nil,
+                                                 0,
+                                                 PXStructuredSyntheticError(PXKeychainBackupErrorNoAccessGroups)),
+                        PXKeychainHelperExitCodeInvalidArguments);
                 }

                 logVerbose(verbose, @"Diagnosing keychain access...");
@@ -460,21 +543,23 @@ int main(int argc, const char *argv[]) {
                            [svc UTF8String] ?: "",
                            [acc UTF8String] ?: "");
                 }
-                PXEmitStructuredResult(PXCreateStructuredResult(structuredOperation,
-                                                                PXKeychainHelperCompletionCompleted,
-                                                                nil,
-                                                                items.count,
-                                                                nil));
-                return 0;
+                return PXFinalizeStructuredResult(
+                    PXCreateStructuredResult(structuredOperation,
+                                             PXKeychainHelperCompletionCompleted,
+                                             nil,
+                                             items.count,
+                                             nil),
+                    PXKeychainHelperExitCodeCompleted);
             }

             default:
-                PXEmitStructuredResult(PXCreateStructuredResult(PXKeychainHelperOperationUnknown,
-                                                                PXKeychainHelperCompletionFailed,
-                                                                nil,
-                                                                0,
-                                                                PXStructuredSyntheticError(PXKeychainBackupErrorInvalidArguments)));
-                return 0;
+                return PXFinalizeStructuredResult(
+                    PXCreateStructuredResult(PXKeychainHelperOperationUnknown,
+                                             PXKeychainHelperCompletionFailed,
+                                             nil,
+                                             0,
+                                             PXStructuredSyntheticError(PXKeychainBackupErrorInvalidArguments)),
+                    PXKeychainHelperExitCodeInvalidArguments);
         }
     }
 }
diff --git a/scripts/keychain_backup.sh b/scripts/keychain_backup.sh
index 99e3274..c5b89d1 100644
--- a/scripts/keychain_backup.sh
+++ b/scripts/keychain_backup.sh
@@ -24,6 +24,20 @@ HELPER_TOOL_PATH="/Library/WeaponX/backup_helper"
 TEMP_DIR="/tmp/keychain_helper_$$"
 VERBOSE=0

+readonly PX_KEYCHAIN_EXIT_COMPLETED=0
+readonly PX_KEYCHAIN_EXIT_PARTIAL=10
+readonly PX_KEYCHAIN_EXIT_INVALID_ARGUMENTS=20
+readonly PX_KEYCHAIN_EXIT_INVALID_INPUT=21
+readonly PX_KEYCHAIN_EXIT_ACCESS_DENIED=30
+readonly PX_KEYCHAIN_EXIT_OPERATION_FAILED=40
+readonly PX_KEYCHAIN_EXIT_PROTOCOL_FAILURE=50
+readonly PX_KEYCHAIN_EXIT_HELPER_UNAVAILABLE=60
+readonly PX_KEYCHAIN_EXIT_TARGET_UNAVAILABLE=61
+readonly PX_KEYCHAIN_EXIT_ENTITLEMENT_FAILURE=62
+readonly PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE=63
+readonly PX_KEYCHAIN_EXIT_SIGNING_FAILURE=64
+readonly PX_KEYCHAIN_EXIT_DEPENDENCY_UNAVAILABLE=65
+
 # Optional subset of keychain groups (CSV) provided by caller.
 OVERRIDE_KEYCHAIN_GROUPS=""

@@ -59,6 +73,23 @@ log_verbose() {
     fi
 }

+normalize_helper_exit_status() {
+    local raw_status="$1"
+    case "$raw_status" in
+        "$PX_KEYCHAIN_EXIT_COMPLETED") return "$PX_KEYCHAIN_EXIT_COMPLETED" ;;
+        "$PX_KEYCHAIN_EXIT_PARTIAL") return "$PX_KEYCHAIN_EXIT_PARTIAL" ;;
+        "$PX_KEYCHAIN_EXIT_INVALID_ARGUMENTS") return "$PX_KEYCHAIN_EXIT_INVALID_ARGUMENTS" ;;
+        "$PX_KEYCHAIN_EXIT_INVALID_INPUT") return "$PX_KEYCHAIN_EXIT_INVALID_INPUT" ;;
+        "$PX_KEYCHAIN_EXIT_ACCESS_DENIED") return "$PX_KEYCHAIN_EXIT_ACCESS_DENIED" ;;
+        "$PX_KEYCHAIN_EXIT_OPERATION_FAILED") return "$PX_KEYCHAIN_EXIT_OPERATION_FAILED" ;;
+        "$PX_KEYCHAIN_EXIT_PROTOCOL_FAILURE") return "$PX_KEYCHAIN_EXIT_PROTOCOL_FAILURE" ;;
+        *)
+            log_error "Unrecognized helper exit status: $raw_status; normalized to $PX_KEYCHAIN_EXIT_OPERATION_FAILED"
+            return "$PX_KEYCHAIN_EXIT_OPERATION_FAILED"
+            ;;
+    esac
+}
+
 cleanup() {
     if [ -d "$TEMP_DIR" ]; then
         rm -rf "$TEMP_DIR"
@@ -210,7 +241,7 @@ extract_entitlements() {

     ldid_path=$(find_ldid) || {
         log_error "ldid not found. Please install ldid."
-        return 1
+        return "$PX_KEYCHAIN_EXIT_DEPENDENCY_UNAVAILABLE"
     }

     log_verbose "Using ldid: $ldid_path"
@@ -220,10 +251,10 @@ extract_entitlements() {

     if [ ! -s "$output_file" ]; then
         log_error "Failed to extract entitlements or app has no entitlements"
-        return 1
+        return "$PX_KEYCHAIN_EXIT_ENTITLEMENT_FAILURE"
     fi

-    return 0
+    return "$PX_KEYCHAIN_EXIT_COMPLETED"
 }

 # === Parse keychain access groups from entitlements ===
@@ -425,11 +456,11 @@ generate_helper_entitlements() {
     # Verify file was created
     if [ ! -f "$output_file" ]; then
         log_error "Failed to create entitlements file: $output_file"
-        return 1
+        return "$PX_KEYCHAIN_EXIT_ENTITLEMENT_FAILURE"
     fi

     log_verbose "Entitlements file created successfully"
-    return 0
+    return "$PX_KEYCHAIN_EXIT_COMPLETED"
 }

 # === Parse application groups from entitlements ===
@@ -476,19 +507,19 @@ resign_helper() {

     ldid_path=$(find_ldid) || {
         log_error "ldid not found"
-        return 1
+        return "$PX_KEYCHAIN_EXIT_DEPENDENCY_UNAVAILABLE"
     }

     # Check if binary exists
     if [ ! -f "$binary_path" ]; then
         log_error "Binary not found at: $binary_path"
-        return 1
+        return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
     fi

     # Check if entitlements file exists
     if [ ! -f "$ent_file" ]; then
         log_error "Entitlements file not found: $ent_file"
-        return 1
+        return "$PX_KEYCHAIN_EXIT_ENTITLEMENT_FAILURE"
     fi

     log_verbose "Resigning binary: $binary_path"
@@ -504,7 +535,7 @@ resign_helper() {
         if [ -n "$ldid_output" ]; then
             log_error "ldid output: $ldid_output"
         fi
-        return 1
+        return "$PX_KEYCHAIN_EXIT_SIGNING_FAILURE"
     fi

     # Verify signing worked
@@ -513,7 +544,7 @@ resign_helper() {
     fi

     log_verbose "Binary resigned successfully"
-    return 0
+    return "$PX_KEYCHAIN_EXIT_COMPLETED"
 }

 # === Main functions ===
@@ -530,7 +561,7 @@ do_backup() {
     local app_binary
     app_binary=$(find_app_executable "$bundle_id") || {
         log_error "Could not find app with bundle ID: $bundle_id"
-        return 1
+        return "$PX_KEYCHAIN_EXIT_TARGET_UNAVAILABLE"
     }
     log_verbose "Found app: $app_binary"

@@ -540,7 +571,11 @@ do_backup() {
     # Extract entitlements
     log_info "Extracting entitlements..."
     local ent_file="$TEMP_DIR/app_ent.xml"
-    extract_entitlements "$app_binary" "$ent_file" || return 1
+    extract_entitlements "$app_binary" "$ent_file"
+    local entitlement_status=$?
+    if [ "$entitlement_status" -ne 0 ]; then
+        return "$entitlement_status"
+    fi

     # Parse keychain groups
     log_info "Parsing keychain access groups..."
@@ -555,7 +590,7 @@ do_backup() {

     if [ -z "$keychain_groups" ]; then
         log_error "No keychain-access-groups found in app entitlements"
-        return 1
+        return "$PX_KEYCHAIN_EXIT_ENTITLEMENT_FAILURE"
     fi
     log_info "Found keychain groups: $keychain_groups"

@@ -595,24 +630,28 @@ do_backup() {
     # Generate helper entitlements
     log_info "Generating helper entitlements..."
     local helper_ent="$TEMP_DIR/helper_ent.plist"
-    if ! generate_helper_entitlements "$keychain_groups" "$app_groups" "$helper_ent" "$app_identifier" "$source_ent_for_system"; then
+    generate_helper_entitlements "$keychain_groups" "$app_groups" "$helper_ent" "$app_identifier" "$source_ent_for_system"
+    local generation_status=$?
+    if [ "$generation_status" -ne 0 ]; then
         log_error "Failed to generate helper entitlements"
-        return 1
+        return "$generation_status"
     fi

     # Prepare working copy of helper tool
     local working_helper="$TEMP_DIR/backup_helper"
     if ! cp "$HELPER_TOOL_PATH" "$working_helper"; then
         log_error "Failed to copy helper tool to temp: $working_helper"
-        return 1
+        return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
     fi
     chmod 755 "$working_helper"

     # Resign helper
     log_info "Resigning KeychainHelper..."
-    if ! resign_helper "$helper_ent" "$working_helper"; then
+    resign_helper "$helper_ent" "$working_helper"
+    local resign_status=$?
+    if [ "$resign_status" -ne 0 ]; then
         log_error "Failed to resign helper tool"
-        return 1
+        return "$resign_status"
     fi

     # Execute backup using the resigned copy
@@ -623,14 +662,16 @@ do_backup() {
     fi
     "$working_helper" "${helper_args[@]}"

+    local raw_exit_code=$?
+    normalize_helper_exit_status "$raw_exit_code"
     local exit_code=$?
-    if [ $exit_code -eq 0 ]; then
+    if [ "$exit_code" -eq "$PX_KEYCHAIN_EXIT_COMPLETED" ]; then
         log_info "Backup completed successfully: $backup_file"
     else
         log_error "Backup failed with exit code: $exit_code"
     fi

-    return $exit_code
+    return "$exit_code"
 }

 do_restore() {
@@ -643,7 +684,7 @@ do_restore() {

     if [ ! -f "$backup_file" ]; then
         log_error "Backup file not found: $backup_file"
-        return 1
+        return "$PX_KEYCHAIN_EXIT_INVALID_INPUT"
     fi

     # Find app executable and resign with its entitlements
@@ -651,14 +692,18 @@ do_restore() {
     local app_binary
     app_binary=$(find_app_executable "$bundle_id") || {
         log_error "Could not find app with bundle ID: $bundle_id"
-        return 1
+        return "$PX_KEYCHAIN_EXIT_TARGET_UNAVAILABLE"
     }

     mkdir -p "$TEMP_DIR"

     log_info "Extracting entitlements..."
     local ent_file="$TEMP_DIR/app_ent.xml"
-    extract_entitlements "$app_binary" "$ent_file" || return 1
+    extract_entitlements "$app_binary" "$ent_file"
+    local entitlement_status=$?
+    if [ "$entitlement_status" -ne 0 ]; then
+        return "$entitlement_status"
+    fi

     local keychain_groups
     keychain_groups=$(parse_keychain_groups "$ent_file")
@@ -687,17 +732,25 @@ do_restore() {

     local helper_ent="$TEMP_DIR/helper_ent.plist"
     generate_helper_entitlements "$keychain_groups" "$app_groups" "$helper_ent" "$app_identifier" "$source_ent_for_system"
+    local generation_status=$?
+    if [ "$generation_status" -ne 0 ]; then
+        return "$generation_status"
+    fi

     # Prepare working copy of helper tool
     local working_helper="$TEMP_DIR/backup_helper"
     if ! cp "$HELPER_TOOL_PATH" "$working_helper"; then
         log_error "Failed to copy helper tool to temp: $working_helper"
-        return 1
+        return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
     fi
     chmod 755 "$working_helper"

     log_info "Resigning KeychainHelper..."
-    resign_helper "$helper_ent" "$working_helper" || return 1
+    resign_helper "$helper_ent" "$working_helper"
+    local resign_status=$?
+    if [ "$resign_status" -ne 0 ]; then
+        return "$resign_status"
+    fi

     # Execute restore using the resigned copy
     log_info "Executing restore..."
@@ -715,14 +768,16 @@ do_restore() {
     fi
     "$working_helper" "${helper_args[@]}"

+    local raw_exit_code=$?
+    normalize_helper_exit_status "$raw_exit_code"
     local exit_code=$?
-    if [ $exit_code -eq 0 ]; then
+    if [ "$exit_code" -eq "$PX_KEYCHAIN_EXIT_COMPLETED" ]; then
         log_info "Restore completed successfully"
     else
         log_error "Restore failed with exit code: $exit_code"
     fi

-    return $exit_code
+    return "$exit_code"
 }

 do_wipe() {
@@ -735,13 +790,17 @@ do_wipe() {
     local app_binary
     app_binary=$(find_app_executable "$bundle_id") || {
         log_error "Could not find app with bundle ID: $bundle_id"
-        return 1
+        return "$PX_KEYCHAIN_EXIT_TARGET_UNAVAILABLE"
     }

     mkdir -p "$TEMP_DIR"

     local ent_file="$TEMP_DIR/app_ent.xml"
-    extract_entitlements "$app_binary" "$ent_file" || return 1
+    extract_entitlements "$app_binary" "$ent_file"
+    local entitlement_status=$?
+    if [ "$entitlement_status" -ne 0 ]; then
+        return "$entitlement_status"
+    fi

     local keychain_groups
     keychain_groups=$(parse_keychain_groups "$ent_file")
@@ -753,7 +812,7 @@ do_wipe() {

     if [ -z "$keychain_groups" ]; then
         log_error "No keychain-access-groups found"
-        return 1
+        return "$PX_KEYCHAIN_EXIT_ENTITLEMENT_FAILURE"
     fi

     log_warn "This will DELETE all keychain items for: $keychain_groups"
@@ -777,16 +836,24 @@ do_wipe() {

     local helper_ent="$TEMP_DIR/helper_ent.plist"
     generate_helper_entitlements "$keychain_groups" "$app_groups" "$helper_ent" "$app_identifier" "$source_ent_for_system"
+    local generation_status=$?
+    if [ "$generation_status" -ne 0 ]; then
+        return "$generation_status"
+    fi

     # Prepare working copy
     local working_helper="$TEMP_DIR/backup_helper"
     if ! cp "$HELPER_TOOL_PATH" "$working_helper"; then
         log_error "Failed to copy helper"
-        return 1
+        return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
     fi
     chmod 755 "$working_helper"

-    resign_helper "$helper_ent" "$working_helper" || return 1
+    resign_helper "$helper_ent" "$working_helper"
+    local resign_status=$?
+    if [ "$resign_status" -ne 0 ]; then
+        return "$resign_status"
+    fi

     local helper_args=("--action" "wipe" "--groups" "$keychain_groups")
     if [ "$VERBOSE" -eq 1 ]; then
@@ -794,6 +861,8 @@ do_wipe() {
     fi
     "$working_helper" "${helper_args[@]}"

+    local raw_exit_code=$?
+    normalize_helper_exit_status "$raw_exit_code"
     return $?
 }

@@ -806,13 +875,17 @@ do_list() {
     local app_binary
     app_binary=$(find_app_executable "$bundle_id") || {
         log_error "Could not find app with bundle ID: $bundle_id"
-        return 1
+        return "$PX_KEYCHAIN_EXIT_TARGET_UNAVAILABLE"
     }

     mkdir -p "$TEMP_DIR"

     local ent_file="$TEMP_DIR/app_ent.xml"
-    extract_entitlements "$app_binary" "$ent_file" || return 1
+    extract_entitlements "$app_binary" "$ent_file"
+    local entitlement_status=$?
+    if [ "$entitlement_status" -ne 0 ]; then
+        return "$entitlement_status"
+    fi

     local keychain_groups
     keychain_groups=$(parse_keychain_groups "$ent_file")
@@ -824,7 +897,7 @@ do_list() {

     if [ -z "$keychain_groups" ]; then
         log_info "No keychain-access-groups found in app"
-        return 0
+        return "$PX_KEYCHAIN_EXIT_COMPLETED"
     fi

     local app_groups
@@ -846,16 +919,24 @@ do_list() {

     local helper_ent="$TEMP_DIR/helper_ent.plist"
     generate_helper_entitlements "$keychain_groups" "$app_groups" "$helper_ent" "$app_identifier" "$source_ent_for_system"
+    local generation_status=$?
+    if [ "$generation_status" -ne 0 ]; then
+        return "$generation_status"
+    fi

     # Prepare working copy
     local working_helper="$TEMP_DIR/backup_helper"
     if ! cp "$HELPER_TOOL_PATH" "$working_helper"; then
         log_error "Failed to copy helper"
-        return 1
+        return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
     fi
     chmod 755 "$working_helper"

-    resign_helper "$helper_ent" "$working_helper" || return 1
+    resign_helper "$helper_ent" "$working_helper"
+    local resign_status=$?
+    if [ "$resign_status" -ne 0 ]; then
+        return "$resign_status"
+    fi

     local helper_args=("--action" "list" "--groups" "$keychain_groups")
     if [ "$VERBOSE" -eq 1 ]; then
@@ -863,6 +944,8 @@ do_list() {
     fi
     "$working_helper" "${helper_args[@]}"

+    local raw_exit_code=$?
+    normalize_helper_exit_status "$raw_exit_code"
     return $?
 }

@@ -890,7 +973,7 @@ print_usage() {
 if [ ! -x "$HELPER_TOOL_PATH" ]; then
     log_error "KeychainHelper not found at: $HELPER_TOOL_PATH"
     log_error "Please ensure the WeaponX package is properly installed"
-    exit 1
+    exit "$PX_KEYCHAIN_EXIT_HELPER_UNAVAILABLE"
 fi

 # Parse global options
@@ -902,7 +985,7 @@ while [[ "$1" == --* ]]; do
             ;;
         --help|-h)
             print_usage
-            exit 0
+            exit "$PX_KEYCHAIN_EXIT_COMPLETED"
             ;;
         *)
             break
@@ -913,7 +996,7 @@ done
 # Require at least action and bundle ID
 if [ $# -lt 2 ]; then
     print_usage
-    exit 1
+    exit "$PX_KEYCHAIN_EXIT_INVALID_ARGUMENTS"
 fi

 ACTION="$1"
@@ -925,7 +1008,7 @@ case "$ACTION" in
         if [ -z "$1" ]; then
             log_error "Backup file path required"
             print_usage
-            exit 1
+            exit "$PX_KEYCHAIN_EXIT_INVALID_ARGUMENTS"
         fi
         shift_file="$1"
         shift
@@ -951,7 +1034,7 @@ case "$ACTION" in
         if [ -z "$1" ]; then
             log_error "Backup file path required"
             print_usage
-            exit 1
+            exit "$PX_KEYCHAIN_EXIT_INVALID_ARGUMENTS"
         fi
         shift_file="$1"
         shift
@@ -1018,8 +1101,8 @@ case "$ACTION" in
     *)
         log_error "Unknown action: $ACTION"
         print_usage
-        exit 1
+        exit "$PX_KEYCHAIN_EXIT_INVALID_ARGUMENTS"
         ;;
 esac

-exit $?
+exit "$?"
```

## Whitespace, CRLF, NUL, and final newline
| File | Bytes | NUL bytes | CRLF sequences | Final LF |
|---|---:|---:|---:|---:|
| `KeychainHelper/PXKeychainHelperExitCode.h` | 784 | 0 | 0 | TRUE |
| `KeychainHelper/backup_helper.m` | 28224 | 0 | 565 | TRUE |
| `scripts/keychain_backup.sh` | 36263 | 0 | 1108 | TRUE |
| `docs/backup-restore-hardening/reports/TASK-4.2-REPORT.md` | SELF-REFERENTIAL | 0 | 0 | TRUE |
- New header/report use UTF-8 LF. Existing CRLF style is retained for `backup_helper.m` and `keychain_backup.sh`. No authorized file contains NUL bytes; all end with LF.

## Build, toolchain, and device risks
- Objective-C/Theos compile and link were not run: `clang.exe`, `make.exe`, and `xcrun.exe` are unavailable and `THEOS` is unset on this Windows host.
- Git Bash syntax validation is authoritative only for parsing, not iOS runtime behavior.
- Device validation remains required for actual process exit propagation through wrapper/callers, signal status behavior on supported jailbreak shells, ldid extraction/signing categories, stdout ordering, and Foundation structured-result construction failure behavior.
- GitHub Actions and source review remain authoritative for Apple SDK compilation, warnings, linking, and package/runtime integration.

GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
