# TASK-5.2 Implementation Report

## Result
IMPLEMENTED. Direct Restore presentation now validates the immutable structured result, distinguishes six high-level outcomes, preserves aggregate warning order, distinguishes component rollback subtypes without claiming whole-Restore rollback, and fails closed for invalid callbacks. Windows static/model gates pass. Apple build/package and physical-device tests remain pending.

## User authority
The user-authorized specification marks TASK-5.1 PASSED and COMPLETED and explicitly opens TASK-5.2. TASK-5.3 is outside this implementation.

## TASK-5.1 review-file status
`docs/backup-restore-hardening/reviews/TASK-5.1-REVIEW.md` is absent. The task specification declares the missing review non-blocking. `TASK-5.1-REPORT.md` remains 54678 bytes with SHA-256 `736d6a38719daf7c9384cca8f728b0ed7078e65f1ba935c5cb32cc34914e4fd6`.

## Baseline
- Required baseline: `8e698940a4b9fe22f48111ac20d7630194d765d8`
- Expected HEAD: `8e69894 phase5(task-5.1): distinguish backup result titles`
- Baseline matched before implementation.

## Working-tree preservation
Pre-existing modifications in coordinator-owned STATUS/ROADMAP/DECISIONS/README files and pre-existing untracked task/review documents were not staged, reset, deleted, rewritten, or normalized. Only the controller and this report are authorized for the implementation commit.

## Exact authorized scope
- `M AppDataBackupRestoreViewController.m`
- `A docs/backup-restore-hardening/reports/TASK-5.2-REPORT.md`
- No public header, manager/model, transaction, batch caller, Keychain source, Makefile, or coordinator document mutation.

## Direct and batch Restore caller inventory
| File | Caller count | Role |
|---|---:|---|
| `AppDataBackupRestoreViewController.m` | 1 | Direct Restore result alert owner |
| `ProjectXViewController.m` | 2 | Batch/quick/RRS Restore flows |
| `ProfileManagerViewController.m` | 0 | No direct Restore caller |

## Current UI defect reproduction
Baseline direct Restore UI mapped every error callback to `Restore Failed`, every nil-error callback to `Restore Complete`, ignored structured rollback state, allowed nil-result apparent success, and created an unused Restore `errAlert`.

## Pre-result-boundary completion contract
Failures before structured-result accumulator acceptance return `result == nil` and `error != nil`. The UI treats these as plain `Restore Failed` and never infers rollback from domain, code, description, transaction name, or filesystem state.

## Post-result-boundary completion contract
Hard failures after the structured-result boundary may return both a valid `PXRestoreResult` and an NSError. A valid result may refine failure into completed-component-rollback or incomplete-rollback subtypes; otherwise the callback remains plain failure.

## Keychain warning-only completion contract
A nil-error valid result with `hasFailures == YES`, failed Keychain, and rollback NotPerformed is presented as `Restore Completed with Component Failures`, never as full success or warning-success. Manager compatibility policy is unchanged.

## Exact six-outcome taxonomy
| Outcome | Classification rule |
|---|---|
| Successful | valid result, all requested succeeded, no failures, no warnings, nil error |
| CompletedWithWarnings | valid all-succeeded result with aggregate warnings |
| CompletedWithComponentFailures | valid nil-error result with failures and no completed/incomplete rollback |
| Failed | hard error without valid rollback subtype, invalid/missing result, or unexpected incomplete execution |
| FailedWithCompletedRollback | valid failed component reports rollback Completed and no incomplete rollback |
| FailedWithIncompleteRollback | valid failed component reports rollback Incomplete; highest safety precedence |

## Exact title contract
| Outcome | Exact title | Literal count |
|---|---|---:|
| Successful | `Restore Successful` | 1 |
| CompletedWithWarnings | `Restore Completed with Warnings` | 1 |
| CompletedWithComponentFailures | `Restore Completed with Component Failures` | 1 |
| Failed | `Restore Failed` | 1 |
| FailedWithCompletedRollback | `Restore Failed: Component Rollback Completed` | 1 |
| FailedWithIncompleteRollback | `Restore Failed: Rollback Incomplete` | 1 |

Exact old literal `@"Restore Complete"` count is 0. Unknown enum values fail closed to `Restore Failed`.

## Presentation validation contract
`PXRestoreResultIsValidForPresentation` requires exact PXRestoreResult/PXRestoreComponentResult/PXRestoreFailure runtime identities, NSArray result/warning collections, eight exact components, a nonzero known requested mask containing ApplicationData, coherent component state, exact aggregate masks, and consistent derived booleans. It reads only immutable result authority and performs no filesystem or manifest inspection.

## Exact component coverage proof
The validator requires exactly one known single-bit result for ApplicationData, ProfileAppData, GlobalSafari, AppGroups, SystemGlobal, SharedSystemDatabases, Preferences, and Keychain. Duplicate, missing, zero, multi-bit, or unknown component values fail validation.

## Component invariant proof
Skipped, NotAttempted, Succeeded, and Failed statuses are checked against requested membership, planned/committed counts, rollback status, warnings, and failure-object requirements. Only Failed components may publish Completed or Incomplete rollback.

## Aggregate-mask proof
Observed component statuses must exactly reproduce succeeded/skipped/notAttempted/failed masks. Masks must be known, pairwise disjoint, union to PXRestoreComponentAll, satisfy requested = succeeded | notAttempted | failed, and skipped = All & ~requested.

## Derived-boolean proof
The validator independently verifies hasWarnings, hasFailures, hasIncompleteRollback, and allRequestedComponentsSucceeded against warnings, masks, and explicit failed-component rollback scans.

## Rollback scan semantics
Completed and Incomplete scanners inspect only components whose status is Failed. They do not inspect warnings, NSError text, failure message text, or nonfailed component rollback fields.

## Incomplete-over-completed precedence
A valid result containing both Completed and Incomplete failed-component rollback states always selects `Restore Failed: Rollback Incomplete`, including nil-error callback anomalies.

## Classifier precedence
1. Validate structured result. 2. Incomplete rollback. 3. Completed rollback. 4. Hard callback error. 5. Missing/invalid result. 6. Component failures without rollback. 7. Unexpected incomplete execution. 8. Warnings. 9. Success.

## Whole-Restore atomicity guard
Completed rollback wording explicitly states that the failed component reported rollback and that components restored earlier were not rolled back. The UI never claims all changes were rolled back, no data changed, or the entire Restore returned to its original state.

## Message contract
- Success: `Data for <application> has been restored.`
- Completed-with-warnings: same base message plus aggregate warning section.
- Component failures: `Restore processing for <application> completed, but one or more requested components failed.`
- Plain failure: usable NSError description or exact fallback `Restore failed without a valid result.`
- Completed component rollback: appends the exact failed-component/earlier-components disclaimer.
- Incomplete rollback: appends the exact safety warning that some data may remain changed.

## Warning compatibility
Aggregate warnings from a valid result are appended after the primary success/failure/rollback explanation. Order and duplicates are preserved exactly. Invalid-result warnings are never read for presentation, and component warning arrays are never merged into a replacement aggregate list.

## Copy Path contract
All six Restore outcomes call the existing presenter with `copyPath:nil`; no Restore Copy Path action or UIPasteboard change was introduced.

## Pending/background behavior
The pending alert fields and delivery/presenter methods remain byte-identical. Exact classified title and message are queued, pendingCopyPath remains nil, and incomplete rollback is not downgraded when the app becomes active.

## Dead-code removal
Whole-controller `UIAlertController *errAlert` occurrence count is 0. The direct Restore callback contains one final best-effort presenter call and no direct result UIAlertController.

## TASK-5.1 backup region hashes
| Protected region | Bytes | SHA-256 | Match |
|---|---:|---|---|
| Backup presentation helpers | 1907 | `eec90ebe21381e18fb5f62579aa90163ee850f544fb46d08e78f15a853366335` | TRUE |
| Pending alert region | 2754 | `00ba8cbbe9952292f0d9d39e0d3db7c4869b4968e3455527d373c8d503d48337` | TRUE |
| Backup button method | 4054 | `a2ab9df97202e358ecd1a92a2f06735ae11707ed21a9b170dbd1935798078a6e` | TRUE |

## ProjectX caller hashes
`ProjectXViewController.m`: 372278 bytes, SHA-256 `b7c5293dfa5d27fdc39c36f236f76306a855eaaf4e9e028f4c2111eb68146162`, two Restore callers, zero baseline diff.

## Manager hash
`AppDataBackupManager.m`: 239969 bytes, SHA-256 `61fc1ff901d64a0b2732c1ea44f47f23209a0b55404fbc69e27889ee03939028`, zero baseline diff.

## PXRestoreResult hashes
- `PXRestoreResult.h`: 4512 bytes, SHA-256 `cb7f2f3e40b3414d329405b1802bf6a9f245f1b660ca983d04776c0af449e69d`
- `PXRestoreResult.m`: 15842 bytes, SHA-256 `c698a854589731f0987379c324d02729f3b586fd0ac3575f9798b77d6207c2fb`
- Both files are byte-identical to baseline.

## Makefile hash
`Makefile`: 9266 bytes, SHA-256 `b2d9ca1083f85b818f132612e792c73e94e78390ef06092db2075439af945dfa`, zero baseline diff.

## Protected production hashes
Protected file count: 32; baseline diff count: 0.

| Path | Bytes | SHA-256 | Baseline-equal |
|---|---:|---|---|
| `AppDataBackupRestoreViewController.h` | 336 | `b470e92a732dca1c97b161f802baf1d3ea8d39706087648e7fc697b63eeba5cf` | TRUE |
| `AppDataBackupManager.h` | 1442 | `b19c1c61e6df642468d713dede5a0c0bd0dbb6a0ac72d98ad6878d3cae1f2e75` | TRUE |
| `AppDataBackupManager.m` | 239969 | `61fc1ff901d64a0b2732c1ea44f47f23209a0b55404fbc69e27889ee03939028` | TRUE |
| `PXRestoreResult.h` | 4512 | `cb7f2f3e40b3414d329405b1802bf6a9f245f1b660ca983d04776c0af449e69d` | TRUE |
| `PXRestoreResult.m` | 15842 | `c698a854589731f0987379c324d02729f3b586fd0ac3575f9798b77d6207c2fb` | TRUE |
| `PXRestorePlan.h` | 4947 | `5cc773132c009fd8eedf4069b33ab53901a530edd580e3231c9d982c60cf7643` | TRUE |
| `PXRestorePlan.m` | 48523 | `cb6f838638a06bc9858b392d123656590291555812c63e3d0ddd4f5529d0d141` | TRUE |
| `PXMainDataRestoreTransaction.h` | 2061 | `df444b03e0214d62e31c89094f7e0afe1037255ab6582928a608ec839466a575` | TRUE |
| `PXMainDataRestoreTransaction.m` | 115847 | `894c40ab599074bc6c481a5b9084c3d557c64fb101336f0495d5297234a5f3c5` | TRUE |
| `PXAppGroupRestoreTransaction.h` | 2235 | `cd329b3f67433214b36d195719e337cc951204c774dd65bbe379eb8936a33412` | TRUE |
| `PXAppGroupRestoreTransaction.m` | 138376 | `842bf9676fdac4c31433f966b81b2b93c82d03225d7f046d7e464a3b402bfbd6` | TRUE |
| `PXOptionalRestoreTransaction.h` | 4050 | `1d162e411824a708209c78325385cff75cea453a8097c93347f02cfb8bf2ad78` | TRUE |
| `PXOptionalRestoreTransaction.m` | 240408 | `b766f73f7b49877ab589f35ae9dc7d0f89e80638526e6c5663777ac6a1a48c1c` | TRUE |
| `PXOptionalRestoreStaging.h` | 4355 | `3d594d5f2eb509e2fb9e87849013ec9428ef7083eb0c4b52ecffe00fa56809c3` | TRUE |
| `PXOptionalRestoreStaging.m` | 104823 | `1e3a0eabba6a5a8a90cb7cf3800476e9324ec4181be1fb51de0e0e08e2c5e39b` | TRUE |
| `PXBackupArtifactVerifier.h` | 2006 | `2cd726496b1830cc404c6e6665e73785552a39c74cdb9683a43d32221fc194cc` | TRUE |
| `PXBackupArtifactVerifier.m` | 46654 | `2c45882144f529380bf485724bdd2258a3d9dd43de232076e857f10f3d5958f9` | TRUE |
| `PXBackupArchiveValidator.h` | 2361 | `661258274d798bfd67356d472334cfffcc1da6a911278ae6e956a66e0cf4b05b` | TRUE |
| `PXBackupArchiveValidator.m` | 89098 | `01c8c628453b8f67853a84ebf9c5511c6a9af454c80bc476da1d9f685eaa306e` | TRUE |
| `ProfileManagerViewController.m` | 159713 | `a26680aa7340f00b913950cd019245066d0854880839403346a965fbf832bb1a` | TRUE |
| `ProjectXViewController.m` | 372278 | `b7c5293dfa5d27fdc39c36f236f76306a855eaaf4e9e028f4c2111eb68146162` | TRUE |
| `scripts/keychain_backup.sh` | 75266 | `46b730b3ca28484232dc7af363bf722e7b7e0d612f54f9250397924847ba2d12` | TRUE |
| `WeaponXKeychainBridge/Tweak.m` | 21970 | `e0733e04eb4915a4753fe59247b17acd5e8cb7f8fa5fcf0bb8dee94f908459aa` | TRUE |
| `Makefile` | 9266 | `b2d9ca1083f85b818f132612e792c73e94e78390ef06092db2075439af945dfa` | TRUE |
| `KeychainHelper/backup_helper.m` | 42561 | `897292e4c7e867ec845502315783ced9b9e5fa53427ac617510f84ba00c543f7` | TRUE |
| `KeychainHelper/KeychainBackupHelper.h` | 4584 | `7e77d560aed48f003f3d068e266dcb9589fbb8eb7bd95139b9dd8d6559eafb6c` | TRUE |
| `KeychainHelper/KeychainBackupHelper.m` | 38587 | `324fbe42dbbc60844d2c53cdacf2c329a6b5b6f945d955c25e91daf32d5c40e2` | TRUE |
| `KeychainHelper/PXKeychainHelperExitCode.h` | 784 | `a0682225ac3ff962305c5bd967f319a4ad0aa7f5eec0a98596e04ba78b21e99a` | TRUE |
| `KeychainHelper/PXKeychainHelperResult.h` | 4083 | `4c8ee54990838de08f2d75a025a5e0777e0f15fe42f25662e1b5661d871520e3` | TRUE |
| `KeychainHelper/PXKeychainHelperResult.m` | 51525 | `1d4a44fb6929743647734881052a4fead70111759390c711bb35aea622f7e1a5` | TRUE |
| `KeychainHelper/PXKeychainItemIdentity.h` | 2387 | `f0a1d1474e2b8887418900c665c0a41f0d9210f5ce5a9bb44c3081803adec9e4` | TRUE |
| `KeychainHelper/PXKeychainItemIdentity.m` | 62919 | `c639d006384271ab304b8b6eca1402331ac50962a055cf4406eca9d720df11df` | TRUE |

## Static source gates
| Gate | Result |
|---|---|
| exact `@"Restore Successful"` | PASS (1) |
| exact `@"Restore Completed with Warnings"` | PASS (1) |
| exact `@"Restore Completed with Component Failures"` | PASS (1) |
| exact `@"Restore Failed"` | PASS (1) |
| exact `@"Restore Failed: Component Rollback Completed"` | PASS (1) |
| exact `@"Restore Failed: Rollback Incomplete"` | PASS (1) |
| exact `@"Restore Complete"` | PASS (0) |
| exact `@"Backup Successful"` | PASS (1) |
| exact `@"Backup Completed with Warnings"` | PASS (1) |
| exact `@"Backup Failed"` | PASS (1) |
| Restore private enum/validator/scanners/classifier/title/warning helper | PASS |
| whole-controller `UIAlertController *errAlert` | PASS (0) |
| Restore callback presenter calls | PASS (1) |
| Restore callback `copyPath:nil` | PASS (1) |
| component-level table/list | PASS (0) |
| manager mutation | PASS (0) |
| balanced delimiters/conflict markers/NUL | PASS |

## Deterministic test model
A temporary external Python model mirrored exact class/array identity, eight-component coverage, component invariants, aggregate masks, derived booleans, rollback scans, classifier precedence, title mapping, message construction, warning preservation, Copy Path, and pending-state behavior. The model and report generator are not part of the implementation commit.
Explicit deterministic scenario assertions executed: 546 PASS.

## Explicit scenarios
Explicit numbered scenario count: 546.

| # | Group | Scenario | Evidence | Status |
|---:|---|---|---|---|
| 1 | Baseline inventory | Required baseline HEAD is exact | Git/source inventory | PASS |
| 2 | Baseline inventory | Expected short commit is 8e69894 phase5(task-5.1) | Git/source inventory | PASS |
| 3 | Baseline inventory | TASK-5.1 report exists | Git/source inventory | PASS |
| 4 | Baseline inventory | TASK-5.1 report baseline hash matches | Git/source inventory | PASS |
| 5 | Baseline inventory | TASK-5.1 review file is absent and non-blocking | Git/source inventory | PASS |
| 6 | Baseline inventory | Controller baseline caller remains one | Git/source inventory | PASS |
| 7 | Baseline inventory | ProjectX restore caller count remains two | Git/source inventory | PASS |
| 8 | Baseline inventory | ProfileManager has no direct Restore caller | Git/source inventory | PASS |
| 9 | Baseline inventory | Protected production set has 32 files | Git/source inventory | PASS |
| 10 | Baseline inventory | Protected production set has zero baseline diff | Git/source inventory | PASS |
| 11 | Baseline inventory | Controller remains UTF-8 decodable | Git/source inventory | PASS |
| 12 | Baseline inventory | Controller remains CRLF-only | Git/source inventory | PASS |
| 13 | Baseline inventory | Coordinator STATUS remains outside authorized scope | Git/source inventory | PASS |
| 14 | Baseline inventory | Coordinator ROADMAP remains outside authorized scope | Git/source inventory | PASS |
| 15 | Baseline inventory | TASK-5.3 report is not created | Git/source inventory | PASS |
| 16 | Baseline inventory | No push operation is part of evidence generation | Git/source inventory | PASS |
| 17 | Exact six-title matrix | Successful maps to exact title Restore Successful | Deterministic model | PASS |
| 18 | Exact six-title matrix | Exact Objective-C literal for Restore Successful occurs once | Static source | PASS |
| 19 | Exact six-title matrix | CompletedWithWarnings maps to exact title Restore Completed with Warnings | Deterministic model | PASS |
| 20 | Exact six-title matrix | Exact Objective-C literal for Restore Completed with Warnings occurs once | Static source | PASS |
| 21 | Exact six-title matrix | CompletedWithComponentFailures maps to exact title Restore Completed with Component Failures | Deterministic model | PASS |
| 22 | Exact six-title matrix | Exact Objective-C literal for Restore Completed with Component Failures occurs once | Static source | PASS |
| 23 | Exact six-title matrix | Failed maps to exact title Restore Failed | Deterministic model | PASS |
| 24 | Exact six-title matrix | Exact Objective-C literal for Restore Failed occurs once | Static source | PASS |
| 25 | Exact six-title matrix | FailedWithCompletedRollback maps to exact title Restore Failed: Component Rollback Completed | Deterministic model | PASS |
| 26 | Exact six-title matrix | Exact Objective-C literal for Restore Failed: Component Rollback Completed occurs once | Static source | PASS |
| 27 | Exact six-title matrix | FailedWithIncompleteRollback maps to exact title Restore Failed: Rollback Incomplete | Deterministic model | PASS |
| 28 | Exact six-title matrix | Exact Objective-C literal for Restore Failed: Rollback Incomplete occurs once | Static source | PASS |
| 29 | Callback error/result combinations | Combination 1 classifies as Successful | Deterministic model | PASS |
| 30 | Callback error/result combinations | Combination 2 classifies as CompletedWithWarnings | Deterministic model | PASS |
| 31 | Callback error/result combinations | Combination 3 classifies as CompletedWithComponentFailures | Deterministic model | PASS |
| 32 | Callback error/result combinations | Combination 4 classifies as Failed | Deterministic model | PASS |
| 33 | Callback error/result combinations | Combination 5 classifies as Failed | Deterministic model | PASS |
| 34 | Callback error/result combinations | Combination 6 classifies as Failed | Deterministic model | PASS |
| 35 | Callback error/result combinations | Combination 7 classifies as Failed | Deterministic model | PASS |
| 36 | Callback error/result combinations | Combination 8 classifies as Failed | Deterministic model | PASS |
| 37 | Callback error/result combinations | Combination 9 classifies as FailedWithCompletedRollback | Deterministic model | PASS |
| 38 | Callback error/result combinations | Combination 10 classifies as FailedWithIncompleteRollback | Deterministic model | PASS |
| 39 | Callback error/result combinations | Combination 11 classifies as FailedWithCompletedRollback | Deterministic model | PASS |
| 40 | Callback error/result combinations | Combination 12 classifies as FailedWithIncompleteRollback | Deterministic model | PASS |
| 41 | Callback error/result combinations | Combination 13 classifies as Failed | Deterministic model | PASS |
| 42 | Callback error/result combinations | Combination 14 classifies as Failed | Deterministic model | PASS |
| 43 | Callback error/result combinations | Combination 15 classifies as CompletedWithComponentFailures | Deterministic model | PASS |
| 44 | Callback error/result combinations | Combination 16 classifies as Failed | Deterministic model | PASS |
| 45 | Callback error/result combinations | Combination 17 classifies as FailedWithCompletedRollback | Deterministic model | PASS |
| 46 | Callback error/result combinations | Combination 18 classifies as FailedWithIncompleteRollback | Deterministic model | PASS |
| 47 | Callback error/result combinations | Combination 19 classifies as Successful | Deterministic model | PASS |
| 48 | Callback error/result combinations | Combination 20 classifies as CompletedWithWarnings | Deterministic model | PASS |
| 49 | Valid result model | Requested mask 0x01 with failed=[] notAttempted=[] remains presentation-valid | Deterministic model | PASS |
| 50 | Valid result model | Requested mask 0x03 with failed=[] notAttempted=[] remains presentation-valid | Deterministic model | PASS |
| 51 | Valid result model | Requested mask 0x05 with failed=[] notAttempted=[] remains presentation-valid | Deterministic model | PASS |
| 52 | Valid result model | Requested mask 0x09 with failed=[] notAttempted=[] remains presentation-valid | Deterministic model | PASS |
| 53 | Valid result model | Requested mask 0x11 with failed=[] notAttempted=[] remains presentation-valid | Deterministic model | PASS |
| 54 | Valid result model | Requested mask 0x21 with failed=[] notAttempted=[] remains presentation-valid | Deterministic model | PASS |
| 55 | Valid result model | Requested mask 0x41 with failed=[] notAttempted=[] remains presentation-valid | Deterministic model | PASS |
| 56 | Valid result model | Requested mask 0x81 with failed=[] notAttempted=[] remains presentation-valid | Deterministic model | PASS |
| 57 | Valid result model | Requested mask 0xff with failed=[128] notAttempted=[] remains presentation-valid | Deterministic model | PASS |
| 58 | Valid result model | Requested mask 0xff with failed=[8] notAttempted=[] remains presentation-valid | Deterministic model | PASS |
| 59 | Valid result model | Requested mask 0xff with failed=[] notAttempted=[128] remains presentation-valid | Deterministic model | PASS |
| 60 | Valid result model | Requested mask 0xff with failed=[] notAttempted=[8, 16] remains presentation-valid | Deterministic model | PASS |
| 61 | Valid result model | Requested mask 0x0f with failed=[8] notAttempted=[] remains presentation-valid | Deterministic model | PASS |
| 62 | Valid result model | Requested mask 0x61 with failed=[] notAttempted=[64] remains presentation-valid | Deterministic model | PASS |
| 63 | Valid result model | Requested mask 0x81 with failed=[128] notAttempted=[] remains presentation-valid | Deterministic model | PASS |
| 64 | Valid result model | Requested mask 0xff with failed=[8, 128] notAttempted=[] remains presentation-valid | Deterministic model | PASS |
| 65 | Invalid result model | nil result fails closed | Deterministic model | PASS |
| 66 | Invalid result model | non-exact PXRestoreResult runtime identity fails closed | Deterministic model | PASS |
| 67 | Invalid result model | componentResults nil fails closed | Deterministic model | PASS |
| 68 | Invalid result model | componentResults count seven fails closed | Deterministic model | PASS |
| 69 | Invalid result model | componentResults count nine fails closed | Deterministic model | PASS |
| 70 | Invalid result model | aggregate warnings nil fails closed | Deterministic model | PASS |
| 71 | Invalid result model | aggregate warnings wrong collection fails closed | Deterministic model | PASS |
| 72 | Invalid result model | aggregate warning empty string fails closed | Deterministic model | PASS |
| 73 | Invalid result model | aggregate warning non-string fails closed | Deterministic model | PASS |
| 74 | Invalid result model | requested mask zero fails closed | Deterministic model | PASS |
| 75 | Invalid result model | requested mask omits ApplicationData fails closed | Deterministic model | PASS |
| 76 | Invalid result model | requested mask contains unknown bit fails closed | Deterministic model | PASS |
| 77 | Invalid result model | component result wrong exact runtime identity fails closed | Deterministic model | PASS |
| 78 | Invalid result model | component value zero fails closed | Deterministic model | PASS |
| 79 | Invalid result model | component value multi-bit fails closed | Deterministic model | PASS |
| 80 | Invalid result model | component value unknown bit fails closed | Deterministic model | PASS |
| 81 | Invalid result model | duplicate component coverage fails closed | Deterministic model | PASS |
| 82 | Invalid result model | unknown component status fails closed | Deterministic model | PASS |
| 83 | Invalid result model | succeeded component planned zero fails closed | Deterministic model | PASS |
| 84 | Invalid result model | succeeded component committed mismatch fails closed | Deterministic model | PASS |
| 85 | Invalid result model | succeeded component publishes rollback fails closed | Deterministic model | PASS |
| 86 | Invalid result model | succeeded component publishes failure fails closed | Deterministic model | PASS |
| 87 | Invalid result model | failed component missing failure fails closed | Deterministic model | PASS |
| 88 | Invalid result model | failed component unknown rollback fails closed | Deterministic model | PASS |
| 89 | Invalid result model | component warnings nil fails closed | Deterministic model | PASS |
| 90 | Invalid result model | component warning empty fails closed | Deterministic model | PASS |
| 91 | Invalid result model | component warning non-string fails closed | Deterministic model | PASS |
| 92 | Invalid result model | succeeded aggregate mask mismatch fails closed | Deterministic model | PASS |
| 93 | Invalid result model | skipped aggregate mask mismatch fails closed | Deterministic model | PASS |
| 94 | Invalid result model | notAttempted aggregate mask mismatch fails closed | Deterministic model | PASS |
| 95 | Invalid result model | failed aggregate mask mismatch fails closed | Deterministic model | PASS |
| 96 | Invalid result model | derived hasWarnings mismatch fails closed | Deterministic model | PASS |
| 97 | Exact eight-component coverage | Canonical result contains exactly one ApplicationData component | Deterministic model | PASS |
| 98 | Exact eight-component coverage | Canonical result contains exactly one ProfileAppData component | Deterministic model | PASS |
| 99 | Exact eight-component coverage | Canonical result contains exactly one GlobalSafari component | Deterministic model | PASS |
| 100 | Exact eight-component coverage | Canonical result contains exactly one AppGroups component | Deterministic model | PASS |
| 101 | Exact eight-component coverage | Canonical result contains exactly one SystemGlobal component | Deterministic model | PASS |
| 102 | Exact eight-component coverage | Canonical result contains exactly one SharedSystemDatabases component | Deterministic model | PASS |
| 103 | Exact eight-component coverage | Canonical result contains exactly one Preferences component | Deterministic model | PASS |
| 104 | Exact eight-component coverage | Canonical result contains exactly one Keychain component | Deterministic model | PASS |
| 105 | Exact eight-component coverage | Coverage remains valid under component array rotation 0 | Deterministic model | PASS |
| 106 | Exact eight-component coverage | Coverage remains valid under component array rotation 1 | Deterministic model | PASS |
| 107 | Exact eight-component coverage | Coverage remains valid under component array rotation 2 | Deterministic model | PASS |
| 108 | Exact eight-component coverage | Coverage remains valid under component array rotation 3 | Deterministic model | PASS |
| 109 | Exact eight-component coverage | Coverage remains valid under component array rotation 4 | Deterministic model | PASS |
| 110 | Exact eight-component coverage | Coverage remains valid under component array rotation 5 | Deterministic model | PASS |
| 111 | Exact eight-component coverage | Coverage remains valid under component array rotation 6 | Deterministic model | PASS |
| 112 | Exact eight-component coverage | Coverage remains valid under component array rotation 7 | Deterministic model | PASS |
| 113 | Unknown component bits | Unknown component bit 0x100 is rejected | Deterministic model | PASS |
| 114 | Unknown component bits | Unknown requested bit 0x100 is rejected | Deterministic model | PASS |
| 115 | Unknown component bits | Unknown component bit 0x200 is rejected | Deterministic model | PASS |
| 116 | Unknown component bits | Unknown requested bit 0x200 is rejected | Deterministic model | PASS |
| 117 | Unknown component bits | Unknown component bit 0x400 is rejected | Deterministic model | PASS |
| 118 | Unknown component bits | Unknown requested bit 0x400 is rejected | Deterministic model | PASS |
| 119 | Unknown component bits | Unknown component bit 0x800 is rejected | Deterministic model | PASS |
| 120 | Unknown component bits | Unknown requested bit 0x800 is rejected | Deterministic model | PASS |
| 121 | Unknown component bits | Unknown component bit 0x1000 is rejected | Deterministic model | PASS |
| 122 | Unknown component bits | Unknown requested bit 0x1000 is rejected | Deterministic model | PASS |
| 123 | Unknown component bits | Unknown component bit 0x2000 is rejected | Deterministic model | PASS |
| 124 | Unknown component bits | Unknown requested bit 0x2000 is rejected | Deterministic model | PASS |
| 125 | Duplicate components | Duplicate ApplicationData entry at alternate position is rejected | Deterministic model | PASS |
| 126 | Duplicate components | Adjacent duplicate at positions 0/1 is rejected | Deterministic model | PASS |
| 127 | Duplicate components | Duplicate ProfileAppData entry at alternate position is rejected | Deterministic model | PASS |
| 128 | Duplicate components | Adjacent duplicate at positions 1/2 is rejected | Deterministic model | PASS |
| 129 | Duplicate components | Duplicate GlobalSafari entry at alternate position is rejected | Deterministic model | PASS |
| 130 | Duplicate components | Adjacent duplicate at positions 2/3 is rejected | Deterministic model | PASS |
| 131 | Duplicate components | Duplicate AppGroups entry at alternate position is rejected | Deterministic model | PASS |
| 132 | Duplicate components | Adjacent duplicate at positions 3/4 is rejected | Deterministic model | PASS |
| 133 | Duplicate components | Duplicate SystemGlobal entry at alternate position is rejected | Deterministic model | PASS |
| 134 | Duplicate components | Adjacent duplicate at positions 4/5 is rejected | Deterministic model | PASS |
| 135 | Duplicate components | Duplicate SharedSystemDatabases entry at alternate position is rejected | Deterministic model | PASS |
| 136 | Duplicate components | Adjacent duplicate at positions 5/6 is rejected | Deterministic model | PASS |
| 137 | Missing components | Missing ApplicationData component is rejected | Deterministic model | PASS |
| 138 | Missing components | Missing ProfileAppData component is rejected | Deterministic model | PASS |
| 139 | Missing components | Missing GlobalSafari component is rejected | Deterministic model | PASS |
| 140 | Missing components | Missing AppGroups component is rejected | Deterministic model | PASS |
| 141 | Missing components | Missing SystemGlobal component is rejected | Deterministic model | PASS |
| 142 | Missing components | Missing SharedSystemDatabases component is rejected | Deterministic model | PASS |
| 143 | Missing components | Missing Preferences component is rejected | Deterministic model | PASS |
| 144 | Missing components | Missing Keychain component is rejected | Deterministic model | PASS |
| 145 | Missing components | Component result cardinality 0 is rejected | Deterministic model | PASS |
| 146 | Missing components | Component result cardinality 1 is rejected | Deterministic model | PASS |
| 147 | Missing components | Component result cardinality 6 is rejected | Deterministic model | PASS |
| 148 | Missing components | Component result cardinality 7 is rejected | Deterministic model | PASS |
| 149 | Status invariants | Succeeded ApplicationData planned count zero is rejected | Deterministic model | PASS |
| 150 | Status invariants | Succeeded ApplicationData committed mismatch is rejected | Deterministic model | PASS |
| 151 | Status invariants | Succeeded ApplicationData rollback completed is rejected | Deterministic model | PASS |
| 152 | Status invariants | Succeeded ApplicationData failure object present is rejected | Deterministic model | PASS |
| 153 | Status invariants | Succeeded ProfileAppData planned count zero is rejected | Deterministic model | PASS |
| 154 | Status invariants | Succeeded ProfileAppData committed mismatch is rejected | Deterministic model | PASS |
| 155 | Status invariants | Succeeded ProfileAppData rollback completed is rejected | Deterministic model | PASS |
| 156 | Status invariants | Succeeded ProfileAppData failure object present is rejected | Deterministic model | PASS |
| 157 | Status invariants | Succeeded GlobalSafari planned count zero is rejected | Deterministic model | PASS |
| 158 | Status invariants | Succeeded GlobalSafari committed mismatch is rejected | Deterministic model | PASS |
| 159 | Status invariants | Succeeded GlobalSafari rollback completed is rejected | Deterministic model | PASS |
| 160 | Status invariants | Succeeded GlobalSafari failure object present is rejected | Deterministic model | PASS |
| 161 | Status invariants | Succeeded AppGroups planned count zero is rejected | Deterministic model | PASS |
| 162 | Status invariants | Succeeded AppGroups committed mismatch is rejected | Deterministic model | PASS |
| 163 | Status invariants | Succeeded AppGroups rollback completed is rejected | Deterministic model | PASS |
| 164 | Status invariants | Succeeded AppGroups failure object present is rejected | Deterministic model | PASS |
| 165 | Status invariants | Succeeded SystemGlobal planned count zero is rejected | Deterministic model | PASS |
| 166 | Status invariants | Succeeded SystemGlobal committed mismatch is rejected | Deterministic model | PASS |
| 167 | Status invariants | Succeeded SystemGlobal rollback completed is rejected | Deterministic model | PASS |
| 168 | Status invariants | Succeeded SystemGlobal failure object present is rejected | Deterministic model | PASS |
| 169 | Status invariants | Skipped ApplicationData planned count nonzero is rejected | Deterministic model | PASS |
| 170 | Status invariants | Skipped ApplicationData warning present is rejected | Deterministic model | PASS |
| 171 | Status invariants | Skipped ApplicationData failure present is rejected | Deterministic model | PASS |
| 172 | Status invariants | Skipped ApplicationData rollback present is rejected | Deterministic model | PASS |
| 173 | Status invariants | Skipped ProfileAppData planned count nonzero is rejected | Deterministic model | PASS |
| 174 | Status invariants | Skipped ProfileAppData warning present is rejected | Deterministic model | PASS |
| 175 | Status invariants | Skipped ProfileAppData failure present is rejected | Deterministic model | PASS |
| 176 | Status invariants | Skipped ProfileAppData rollback present is rejected | Deterministic model | PASS |
| 177 | Status invariants | Skipped GlobalSafari planned count nonzero is rejected | Deterministic model | PASS |
| 178 | Status invariants | Skipped GlobalSafari warning present is rejected | Deterministic model | PASS |
| 179 | Status invariants | Skipped GlobalSafari failure present is rejected | Deterministic model | PASS |
| 180 | Status invariants | Skipped GlobalSafari rollback present is rejected | Deterministic model | PASS |
| 181 | Status invariants | Skipped AppGroups planned count nonzero is rejected | Deterministic model | PASS |
| 182 | Status invariants | Skipped AppGroups warning present is rejected | Deterministic model | PASS |
| 183 | Status invariants | Skipped AppGroups failure present is rejected | Deterministic model | PASS |
| 184 | Status invariants | Skipped AppGroups rollback present is rejected | Deterministic model | PASS |
| 185 | Status invariants | Skipped SystemGlobal planned count nonzero is rejected | Deterministic model | PASS |
| 186 | Status invariants | Skipped SystemGlobal warning present is rejected | Deterministic model | PASS |
| 187 | Status invariants | Skipped SystemGlobal failure present is rejected | Deterministic model | PASS |
| 188 | Status invariants | Skipped SystemGlobal rollback present is rejected | Deterministic model | PASS |
| 189 | Rollback invariants | Completed rollback on succeeded ApplicationData is rejected | Deterministic model | PASS |
| 190 | Rollback invariants | Incomplete rollback on skipped ApplicationData is rejected | Deterministic model | PASS |
| 191 | Rollback invariants | Unknown rollback value on failed ApplicationData is rejected | Deterministic model | PASS |
| 192 | Rollback invariants | Completed rollback on succeeded ProfileAppData is rejected | Deterministic model | PASS |
| 193 | Rollback invariants | Incomplete rollback on skipped ProfileAppData is rejected | Deterministic model | PASS |
| 194 | Rollback invariants | Unknown rollback value on failed ProfileAppData is rejected | Deterministic model | PASS |
| 195 | Rollback invariants | Completed rollback on succeeded GlobalSafari is rejected | Deterministic model | PASS |
| 196 | Rollback invariants | Incomplete rollback on skipped GlobalSafari is rejected | Deterministic model | PASS |
| 197 | Rollback invariants | Unknown rollback value on failed GlobalSafari is rejected | Deterministic model | PASS |
| 198 | Rollback invariants | Completed rollback on succeeded AppGroups is rejected | Deterministic model | PASS |
| 199 | Rollback invariants | Incomplete rollback on skipped AppGroups is rejected | Deterministic model | PASS |
| 200 | Rollback invariants | Unknown rollback value on failed AppGroups is rejected | Deterministic model | PASS |
| 201 | Rollback invariants | Completed rollback on succeeded SystemGlobal is rejected | Deterministic model | PASS |
| 202 | Rollback invariants | Incomplete rollback on skipped SystemGlobal is rejected | Deterministic model | PASS |
| 203 | Rollback invariants | Unknown rollback value on failed SystemGlobal is rejected | Deterministic model | PASS |
| 204 | Rollback invariants | Completed rollback on succeeded SharedSystemDatabases is rejected | Deterministic model | PASS |
| 205 | Rollback invariants | Incomplete rollback on skipped SharedSystemDatabases is rejected | Deterministic model | PASS |
| 206 | Rollback invariants | Unknown rollback value on failed SharedSystemDatabases is rejected | Deterministic model | PASS |
| 207 | Rollback invariants | Completed rollback on succeeded Preferences is rejected | Deterministic model | PASS |
| 208 | Rollback invariants | Incomplete rollback on skipped Preferences is rejected | Deterministic model | PASS |
| 209 | Rollback invariants | Unknown rollback value on failed Preferences is rejected | Deterministic model | PASS |
| 210 | Rollback invariants | Completed rollback on succeeded Keychain is rejected | Deterministic model | PASS |
| 211 | Rollback invariants | Incomplete rollback on skipped Keychain is rejected | Deterministic model | PASS |
| 212 | Rollback invariants | Unknown rollback value on failed Keychain is rejected | Deterministic model | PASS |
| 213 | Aggregate masks | Observed succeeded mask mismatch for ApplicationData is rejected | Deterministic model | PASS |
| 214 | Aggregate masks | Observed skipped mask mismatch for ApplicationData is rejected | Deterministic model | PASS |
| 215 | Aggregate masks | Observed notAttempted mask mismatch for ApplicationData is rejected | Deterministic model | PASS |
| 216 | Aggregate masks | Observed succeeded mask mismatch for ProfileAppData is rejected | Deterministic model | PASS |
| 217 | Aggregate masks | Observed skipped mask mismatch for ProfileAppData is rejected | Deterministic model | PASS |
| 218 | Aggregate masks | Observed notAttempted mask mismatch for ProfileAppData is rejected | Deterministic model | PASS |
| 219 | Aggregate masks | Observed succeeded mask mismatch for GlobalSafari is rejected | Deterministic model | PASS |
| 220 | Aggregate masks | Observed skipped mask mismatch for GlobalSafari is rejected | Deterministic model | PASS |
| 221 | Aggregate masks | Observed notAttempted mask mismatch for GlobalSafari is rejected | Deterministic model | PASS |
| 222 | Aggregate masks | Observed succeeded mask mismatch for AppGroups is rejected | Deterministic model | PASS |
| 223 | Aggregate masks | Observed skipped mask mismatch for AppGroups is rejected | Deterministic model | PASS |
| 224 | Aggregate masks | Observed notAttempted mask mismatch for AppGroups is rejected | Deterministic model | PASS |
| 225 | Aggregate masks | Observed succeeded mask mismatch for SystemGlobal is rejected | Deterministic model | PASS |
| 226 | Aggregate masks | Observed skipped mask mismatch for SystemGlobal is rejected | Deterministic model | PASS |
| 227 | Aggregate masks | Observed notAttempted mask mismatch for SystemGlobal is rejected | Deterministic model | PASS |
| 228 | Aggregate masks | Observed succeeded mask mismatch for SharedSystemDatabases is rejected | Deterministic model | PASS |
| 229 | Aggregate masks | Observed skipped mask mismatch for SharedSystemDatabases is rejected | Deterministic model | PASS |
| 230 | Aggregate masks | Observed notAttempted mask mismatch for SharedSystemDatabases is rejected | Deterministic model | PASS |
| 231 | Aggregate masks | Observed succeeded mask mismatch for Preferences is rejected | Deterministic model | PASS |
| 232 | Aggregate masks | Observed skipped mask mismatch for Preferences is rejected | Deterministic model | PASS |
| 233 | Aggregate masks | Observed notAttempted mask mismatch for Preferences is rejected | Deterministic model | PASS |
| 234 | Aggregate masks | Observed succeeded mask mismatch for Keychain is rejected | Deterministic model | PASS |
| 235 | Aggregate masks | Observed skipped mask mismatch for Keychain is rejected | Deterministic model | PASS |
| 236 | Aggregate masks | Observed notAttempted mask mismatch for Keychain is rejected | Deterministic model | PASS |
| 237 | Boolean consistency | hasWarnings false with aggregate warning for ApplicationData is rejected | Deterministic model | PASS |
| 238 | Boolean consistency | hasFailures false with failed ApplicationData is rejected | Deterministic model | PASS |
| 239 | Boolean consistency | hasWarnings false with aggregate warning for ProfileAppData is rejected | Deterministic model | PASS |
| 240 | Boolean consistency | hasFailures false with failed ProfileAppData is rejected | Deterministic model | PASS |
| 241 | Boolean consistency | hasWarnings false with aggregate warning for GlobalSafari is rejected | Deterministic model | PASS |
| 242 | Boolean consistency | hasFailures false with failed GlobalSafari is rejected | Deterministic model | PASS |
| 243 | Boolean consistency | hasWarnings false with aggregate warning for AppGroups is rejected | Deterministic model | PASS |
| 244 | Boolean consistency | hasFailures false with failed AppGroups is rejected | Deterministic model | PASS |
| 245 | Boolean consistency | hasWarnings false with aggregate warning for SystemGlobal is rejected | Deterministic model | PASS |
| 246 | Boolean consistency | hasFailures false with failed SystemGlobal is rejected | Deterministic model | PASS |
| 247 | Boolean consistency | hasWarnings false with aggregate warning for SharedSystemDatabases is rejected | Deterministic model | PASS |
| 248 | Boolean consistency | hasFailures false with failed SharedSystemDatabases is rejected | Deterministic model | PASS |
| 249 | Boolean consistency | hasWarnings false with aggregate warning for Preferences is rejected | Deterministic model | PASS |
| 250 | Boolean consistency | hasFailures false with failed Preferences is rejected | Deterministic model | PASS |
| 251 | Boolean consistency | hasWarnings false with aggregate warning for Keychain is rejected | Deterministic model | PASS |
| 252 | Boolean consistency | hasFailures false with failed Keychain is rejected | Deterministic model | PASS |
| 253 | Warning validation | Aggregate warning shape variant 1 is rejected | Deterministic model | PASS |
| 254 | Warning validation | Component warning shape variant 1 is rejected | Deterministic model | PASS |
| 255 | Warning validation | Failed-component warning shape variant 1 is rejected | Deterministic model | PASS |
| 256 | Warning validation | Aggregate warning shape variant 2 is rejected | Deterministic model | PASS |
| 257 | Warning validation | Component warning shape variant 2 is rejected | Deterministic model | PASS |
| 258 | Warning validation | Failed-component warning shape variant 2 is rejected | Deterministic model | PASS |
| 259 | Warning validation | Aggregate warning shape variant 3 is rejected | Deterministic model | PASS |
| 260 | Warning validation | Component warning shape variant 3 is rejected | Deterministic model | PASS |
| 261 | Warning validation | Failed-component warning shape variant 3 is rejected | Deterministic model | PASS |
| 262 | Warning validation | Aggregate warning shape variant 4 is rejected | Deterministic model | PASS |
| 263 | Warning validation | Component warning shape variant 4 is rejected | Deterministic model | PASS |
| 264 | Warning validation | Failed-component warning shape variant 4 is rejected | Deterministic model | PASS |
| 265 | Warning validation | Aggregate warning shape variant 5 is rejected | Deterministic model | PASS |
| 266 | Warning validation | Component warning shape variant 5 is rejected | Deterministic model | PASS |
| 267 | Warning validation | Failed-component warning shape variant 5 is rejected | Deterministic model | PASS |
| 268 | Warning validation | Aggregate warning shape variant 6 is rejected | Deterministic model | PASS |
| 269 | Warning validation | Component warning shape variant 6 is rejected | Deterministic model | PASS |
| 270 | Warning validation | Failed-component warning shape variant 6 is rejected | Deterministic model | PASS |
| 271 | Warning validation | Aggregate warning shape variant 7 is rejected | Deterministic model | PASS |
| 272 | Warning validation | Component warning shape variant 7 is rejected | Deterministic model | PASS |
| 273 | Warning validation | Failed-component warning shape variant 7 is rejected | Deterministic model | PASS |
| 274 | Warning validation | Aggregate warning shape variant 8 is rejected | Deterministic model | PASS |
| 275 | Warning validation | Component warning shape variant 8 is rejected | Deterministic model | PASS |
| 276 | Warning validation | Failed-component warning shape variant 8 is rejected | Deterministic model | PASS |
| 277 | Warning order and duplicates | Aggregate warning order is preserved for cardinality 1 | Deterministic model | PASS |
| 278 | Warning order and duplicates | Single warning is not duplicated or removed | Deterministic model | PASS |
| 279 | Warning order and duplicates | Aggregate warning order is preserved for cardinality 2 | Deterministic model | PASS |
| 280 | Warning order and duplicates | Duplicate warning-0 cardinality 1 is preserved for size 2 | Deterministic model | PASS |
| 281 | Warning order and duplicates | Aggregate warning order is preserved for cardinality 3 | Deterministic model | PASS |
| 282 | Warning order and duplicates | Duplicate warning-0 cardinality 1 is preserved for size 3 | Deterministic model | PASS |
| 283 | Warning order and duplicates | Aggregate warning order is preserved for cardinality 4 | Deterministic model | PASS |
| 284 | Warning order and duplicates | Duplicate warning-0 cardinality 2 is preserved for size 4 | Deterministic model | PASS |
| 285 | Warning order and duplicates | Aggregate warning order is preserved for cardinality 8 | Deterministic model | PASS |
| 286 | Warning order and duplicates | Duplicate warning-0 cardinality 3 is preserved for size 8 | Deterministic model | PASS |
| 287 | Warning order and duplicates | Aggregate warning order is preserved for cardinality 16 | Deterministic model | PASS |
| 288 | Warning order and duplicates | Duplicate warning-0 cardinality 6 is preserved for size 16 | Deterministic model | PASS |
| 289 | Warning order and duplicates | Aggregate warning order is preserved for cardinality 32 | Deterministic model | PASS |
| 290 | Warning order and duplicates | Duplicate warning-0 cardinality 11 is preserved for size 32 | Deterministic model | PASS |
| 291 | Warning order and duplicates | Aggregate warning order is preserved for cardinality 64 | Deterministic model | PASS |
| 292 | Warning order and duplicates | Duplicate warning-0 cardinality 22 is preserved for size 64 | Deterministic model | PASS |
| 293 | Success | Requested mask 0x01 yields exact success presentation | Deterministic model | PASS |
| 294 | Success | Requested mask 0x03 yields exact success presentation | Deterministic model | PASS |
| 295 | Success | Requested mask 0x05 yields exact success presentation | Deterministic model | PASS |
| 296 | Success | Requested mask 0x09 yields exact success presentation | Deterministic model | PASS |
| 297 | Success | Requested mask 0x11 yields exact success presentation | Deterministic model | PASS |
| 298 | Success | Requested mask 0x21 yields exact success presentation | Deterministic model | PASS |
| 299 | Success | Requested mask 0x41 yields exact success presentation | Deterministic model | PASS |
| 300 | Success | Requested mask 0x81 yields exact success presentation | Deterministic model | PASS |
| 301 | Success | Requested mask 0x07 yields exact success presentation | Deterministic model | PASS |
| 302 | Success | Requested mask 0x19 yields exact success presentation | Deterministic model | PASS |
| 303 | Success | Requested mask 0x61 yields exact success presentation | Deterministic model | PASS |
| 304 | Success | Requested mask 0xff yields exact success presentation | Deterministic model | PASS |
| 305 | Warning success | All-succeeded result with 1 aggregate warnings uses warning-success title | Deterministic model | PASS |
| 306 | Warning success | All-succeeded result with 2 aggregate warnings uses warning-success title | Deterministic model | PASS |
| 307 | Warning success | All-succeeded result with 3 aggregate warnings uses warning-success title | Deterministic model | PASS |
| 308 | Warning success | All-succeeded result with 4 aggregate warnings uses warning-success title | Deterministic model | PASS |
| 309 | Warning success | All-succeeded result with 8 aggregate warnings uses warning-success title | Deterministic model | PASS |
| 310 | Warning success | All-succeeded result with 16 aggregate warnings uses warning-success title | Deterministic model | PASS |
| 311 | Warning success | All-succeeded result with 32 aggregate warnings uses warning-success title | Deterministic model | PASS |
| 312 | Warning success | All-succeeded result with 64 aggregate warnings uses warning-success title | Deterministic model | PASS |
| 313 | Warning success | All-succeeded result with 128 aggregate warnings uses warning-success title | Deterministic model | PASS |
| 314 | Warning success | All-succeeded result with 256 aggregate warnings uses warning-success title | Deterministic model | PASS |
| 315 | Warning success | All-succeeded result with 512 aggregate warnings uses warning-success title | Deterministic model | PASS |
| 316 | Warning success | All-succeeded result with 1024 aggregate warnings uses warning-success title | Deterministic model | PASS |
| 317 | Keychain warning-only failure | Keychain NotPerformed failure with 1 aggregate warnings is not success | Deterministic model | PASS |
| 318 | Keychain warning-only failure | Keychain NotPerformed failure with 2 aggregate warnings is not success | Deterministic model | PASS |
| 319 | Keychain warning-only failure | Keychain NotPerformed failure with 3 aggregate warnings is not success | Deterministic model | PASS |
| 320 | Keychain warning-only failure | Keychain NotPerformed failure with 4 aggregate warnings is not success | Deterministic model | PASS |
| 321 | Keychain warning-only failure | Keychain NotPerformed failure with 5 aggregate warnings is not success | Deterministic model | PASS |
| 322 | Keychain warning-only failure | Keychain NotPerformed failure with 6 aggregate warnings is not success | Deterministic model | PASS |
| 323 | Keychain warning-only failure | Keychain NotPerformed failure with 7 aggregate warnings is not success | Deterministic model | PASS |
| 324 | Keychain warning-only failure | Keychain NotPerformed failure with 8 aggregate warnings is not success | Deterministic model | PASS |
| 325 | Keychain warning-only failure | Keychain NotPerformed failure with 9 aggregate warnings is not success | Deterministic model | PASS |
| 326 | Keychain warning-only failure | Keychain NotPerformed failure with 10 aggregate warnings is not success | Deterministic model | PASS |
| 327 | Keychain warning-only failure | Keychain NotPerformed failure with 11 aggregate warnings is not success | Deterministic model | PASS |
| 328 | Keychain warning-only failure | Keychain NotPerformed failure with 12 aggregate warnings is not success | Deterministic model | PASS |
| 329 | Pre-boundary failure | Pre-boundary error 'Missing parameters' stays plain failure without rollback claim | Deterministic model | PASS |
| 330 | Pre-boundary failure | Pre-boundary error 'Manifest missing or invalid' stays plain failure without rollback claim | Deterministic model | PASS |
| 331 | Pre-boundary failure | Pre-boundary error 'Bundle identity mismatch' stays plain failure without rollback claim | Deterministic model | PASS |
| 332 | Pre-boundary failure | Pre-boundary error 'Artifact verification failed' stays plain failure without rollback claim | Deterministic model | PASS |
| 333 | Pre-boundary failure | Pre-boundary error 'Archive validation failed' stays plain failure without rollback claim | Deterministic model | PASS |
| 334 | Pre-boundary failure | Pre-boundary error 'Restore plan construction failed' stays plain failure without rollback claim | Deterministic model | PASS |
| 335 | Pre-boundary failure | Pre-boundary error 'tar not found' stays plain failure without rollback claim | Deterministic model | PASS |
| 336 | Pre-boundary failure | Pre-boundary error 'App Group target plan failed' stays plain failure without rollback claim | Deterministic model | PASS |
| 337 | Pre-boundary failure | Pre-boundary error 'Optional destination plan failed' stays plain failure without rollback claim | Deterministic model | PASS |
| 338 | Pre-boundary failure | Pre-boundary error 'Structured result construction failed' stays plain failure without rollback claim | Deterministic model | PASS |
| 339 | Pre-boundary failure | Pre-boundary error 'Invalid input' stays plain failure without rollback claim | Deterministic model | PASS |
| 340 | Pre-boundary failure | Pre-boundary error 'Pre-boundary hard failure' stays plain failure without rollback claim | Deterministic model | PASS |
| 341 | Post-boundary failure | Valid structured ApplicationData NotPerformed failure plus error remains plain failure | Deterministic model | PASS |
| 342 | Post-boundary failure | Valid structured ApplicationData failure appends aggregate warning after error | Deterministic model | PASS |
| 343 | Post-boundary failure | Valid structured ProfileAppData NotPerformed failure plus error remains plain failure | Deterministic model | PASS |
| 344 | Post-boundary failure | Valid structured ProfileAppData failure appends aggregate warning after error | Deterministic model | PASS |
| 345 | Post-boundary failure | Valid structured GlobalSafari NotPerformed failure plus error remains plain failure | Deterministic model | PASS |
| 346 | Post-boundary failure | Valid structured GlobalSafari failure appends aggregate warning after error | Deterministic model | PASS |
| 347 | Post-boundary failure | Valid structured AppGroups NotPerformed failure plus error remains plain failure | Deterministic model | PASS |
| 348 | Post-boundary failure | Valid structured AppGroups failure appends aggregate warning after error | Deterministic model | PASS |
| 349 | Post-boundary failure | Valid structured SystemGlobal NotPerformed failure plus error remains plain failure | Deterministic model | PASS |
| 350 | Post-boundary failure | Valid structured SystemGlobal failure appends aggregate warning after error | Deterministic model | PASS |
| 351 | Post-boundary failure | Valid structured SharedSystemDatabases NotPerformed failure plus error remains plain failure | Deterministic model | PASS |
| 352 | Post-boundary failure | Valid structured SharedSystemDatabases failure appends aggregate warning after error | Deterministic model | PASS |
| 353 | Post-boundary failure | Valid structured Preferences NotPerformed failure plus error remains plain failure | Deterministic model | PASS |
| 354 | Post-boundary failure | Valid structured Preferences failure appends aggregate warning after error | Deterministic model | PASS |
| 355 | Post-boundary failure | Valid structured Keychain NotPerformed failure plus error remains plain failure | Deterministic model | PASS |
| 356 | Post-boundary failure | Valid structured Keychain failure appends aggregate warning after error | Deterministic model | PASS |
| 357 | Rollback NotPerformed | Nil-error failed ApplicationData with NotPerformed maps to completed-with-component-failures | Deterministic model | PASS |
| 358 | Rollback NotPerformed | Nil-error failed ProfileAppData with NotPerformed maps to completed-with-component-failures | Deterministic model | PASS |
| 359 | Rollback NotPerformed | Nil-error failed GlobalSafari with NotPerformed maps to completed-with-component-failures | Deterministic model | PASS |
| 360 | Rollback NotPerformed | Nil-error failed AppGroups with NotPerformed maps to completed-with-component-failures | Deterministic model | PASS |
| 361 | Rollback NotPerformed | Nil-error failed SystemGlobal with NotPerformed maps to completed-with-component-failures | Deterministic model | PASS |
| 362 | Rollback NotPerformed | Nil-error failed SharedSystemDatabases with NotPerformed maps to completed-with-component-failures | Deterministic model | PASS |
| 363 | Rollback NotPerformed | Nil-error failed Preferences with NotPerformed maps to completed-with-component-failures | Deterministic model | PASS |
| 364 | Rollback NotPerformed | Nil-error failed Keychain with NotPerformed maps to completed-with-component-failures | Deterministic model | PASS |
| 365 | Rollback NotPerformed | Hard-error failed ApplicationData with NotPerformed maps to plain failure | Deterministic model | PASS |
| 366 | Rollback NotPerformed | Hard-error failed ProfileAppData with NotPerformed maps to plain failure | Deterministic model | PASS |
| 367 | Rollback NotPerformed | Hard-error failed GlobalSafari with NotPerformed maps to plain failure | Deterministic model | PASS |
| 368 | Rollback NotPerformed | Hard-error failed AppGroups with NotPerformed maps to plain failure | Deterministic model | PASS |
| 369 | Rollback Completed | Hard-error ApplicationData completed rollback selects exact subtype | Deterministic model | PASS |
| 370 | Rollback Completed | Nil-error anomaly for ApplicationData completed rollback still selects subtype | Deterministic model | PASS |
| 371 | Rollback Completed | Hard-error ProfileAppData completed rollback selects exact subtype | Deterministic model | PASS |
| 372 | Rollback Completed | Nil-error anomaly for ProfileAppData completed rollback still selects subtype | Deterministic model | PASS |
| 373 | Rollback Completed | Hard-error GlobalSafari completed rollback selects exact subtype | Deterministic model | PASS |
| 374 | Rollback Completed | Nil-error anomaly for GlobalSafari completed rollback still selects subtype | Deterministic model | PASS |
| 375 | Rollback Completed | Hard-error AppGroups completed rollback selects exact subtype | Deterministic model | PASS |
| 376 | Rollback Completed | Nil-error anomaly for AppGroups completed rollback still selects subtype | Deterministic model | PASS |
| 377 | Rollback Completed | Hard-error SystemGlobal completed rollback selects exact subtype | Deterministic model | PASS |
| 378 | Rollback Completed | Nil-error anomaly for SystemGlobal completed rollback still selects subtype | Deterministic model | PASS |
| 379 | Rollback Completed | Hard-error SharedSystemDatabases completed rollback selects exact subtype | Deterministic model | PASS |
| 380 | Rollback Completed | Nil-error anomaly for SharedSystemDatabases completed rollback still selects subtype | Deterministic model | PASS |
| 381 | Rollback Completed | Hard-error Preferences completed rollback selects exact subtype | Deterministic model | PASS |
| 382 | Rollback Completed | Nil-error anomaly for Preferences completed rollback still selects subtype | Deterministic model | PASS |
| 383 | Rollback Completed | Hard-error Keychain completed rollback selects exact subtype | Deterministic model | PASS |
| 384 | Rollback Completed | Nil-error anomaly for Keychain completed rollback still selects subtype | Deterministic model | PASS |
| 385 | Rollback Incomplete | Hard-error ApplicationData incomplete rollback selects highest-safety subtype | Deterministic model | PASS |
| 386 | Rollback Incomplete | Nil-error anomaly for ApplicationData incomplete rollback still selects highest-safety subtype | Deterministic model | PASS |
| 387 | Rollback Incomplete | Hard-error ProfileAppData incomplete rollback selects highest-safety subtype | Deterministic model | PASS |
| 388 | Rollback Incomplete | Nil-error anomaly for ProfileAppData incomplete rollback still selects highest-safety subtype | Deterministic model | PASS |
| 389 | Rollback Incomplete | Hard-error GlobalSafari incomplete rollback selects highest-safety subtype | Deterministic model | PASS |
| 390 | Rollback Incomplete | Nil-error anomaly for GlobalSafari incomplete rollback still selects highest-safety subtype | Deterministic model | PASS |
| 391 | Rollback Incomplete | Hard-error AppGroups incomplete rollback selects highest-safety subtype | Deterministic model | PASS |
| 392 | Rollback Incomplete | Nil-error anomaly for AppGroups incomplete rollback still selects highest-safety subtype | Deterministic model | PASS |
| 393 | Rollback Incomplete | Hard-error SystemGlobal incomplete rollback selects highest-safety subtype | Deterministic model | PASS |
| 394 | Rollback Incomplete | Nil-error anomaly for SystemGlobal incomplete rollback still selects highest-safety subtype | Deterministic model | PASS |
| 395 | Rollback Incomplete | Hard-error SharedSystemDatabases incomplete rollback selects highest-safety subtype | Deterministic model | PASS |
| 396 | Rollback Incomplete | Nil-error anomaly for SharedSystemDatabases incomplete rollback still selects highest-safety subtype | Deterministic model | PASS |
| 397 | Rollback Incomplete | Hard-error Preferences incomplete rollback selects highest-safety subtype | Deterministic model | PASS |
| 398 | Rollback Incomplete | Nil-error anomaly for Preferences incomplete rollback still selects highest-safety subtype | Deterministic model | PASS |
| 399 | Rollback Incomplete | Hard-error Keychain incomplete rollback selects highest-safety subtype | Deterministic model | PASS |
| 400 | Rollback Incomplete | Nil-error anomaly for Keychain incomplete rollback still selects highest-safety subtype | Deterministic model | PASS |
| 401 | Mixed rollback precedence | Completed AppGroups plus incomplete Keychain selects incomplete | Deterministic model | PASS |
| 402 | Mixed rollback precedence | Nil-error mixed rollback anomaly AppGroups/Keychain selects incomplete | Deterministic model | PASS |
| 403 | Mixed rollback precedence | Completed ProfileAppData plus incomplete GlobalSafari selects incomplete | Deterministic model | PASS |
| 404 | Mixed rollback precedence | Nil-error mixed rollback anomaly ProfileAppData/GlobalSafari selects incomplete | Deterministic model | PASS |
| 405 | Mixed rollback precedence | Completed SystemGlobal plus incomplete SharedSystemDatabases selects incomplete | Deterministic model | PASS |
| 406 | Mixed rollback precedence | Nil-error mixed rollback anomaly SystemGlobal/SharedSystemDatabases selects incomplete | Deterministic model | PASS |
| 407 | Mixed rollback precedence | Completed Preferences plus incomplete Keychain selects incomplete | Deterministic model | PASS |
| 408 | Mixed rollback precedence | Nil-error mixed rollback anomaly Preferences/Keychain selects incomplete | Deterministic model | PASS |
| 409 | Mixed rollback precedence | Completed ApplicationData plus incomplete AppGroups selects incomplete | Deterministic model | PASS |
| 410 | Mixed rollback precedence | Nil-error mixed rollback anomaly ApplicationData/AppGroups selects incomplete | Deterministic model | PASS |
| 411 | Mixed rollback precedence | Completed GlobalSafari plus incomplete SystemGlobal selects incomplete | Deterministic model | PASS |
| 412 | Mixed rollback precedence | Nil-error mixed rollback anomaly GlobalSafari/SystemGlobal selects incomplete | Deterministic model | PASS |
| 413 | Whole-Restore atomicity guard | Earlier successful components plus AppGroups completed rollback never claim whole-Restore rollback | Deterministic model | PASS |
| 414 | Whole-Restore atomicity guard | Completed rollback message for AppGroups avoids no-change claims | Deterministic model | PASS |
| 415 | Whole-Restore atomicity guard | Earlier successful components plus SystemGlobal completed rollback never claim whole-Restore rollback | Deterministic model | PASS |
| 416 | Whole-Restore atomicity guard | Completed rollback message for SystemGlobal avoids no-change claims | Deterministic model | PASS |
| 417 | Whole-Restore atomicity guard | Earlier successful components plus SharedSystemDatabases completed rollback never claim whole-Restore rollback | Deterministic model | PASS |
| 418 | Whole-Restore atomicity guard | Completed rollback message for SharedSystemDatabases avoids no-change claims | Deterministic model | PASS |
| 419 | Whole-Restore atomicity guard | Earlier successful components plus Preferences completed rollback never claim whole-Restore rollback | Deterministic model | PASS |
| 420 | Whole-Restore atomicity guard | Completed rollback message for Preferences avoids no-change claims | Deterministic model | PASS |
| 421 | Whole-Restore atomicity guard | Earlier successful components plus Keychain completed rollback never claim whole-Restore rollback | Deterministic model | PASS |
| 422 | Whole-Restore atomicity guard | Completed rollback message for Keychain avoids no-change claims | Deterministic model | PASS |
| 423 | Whole-Restore atomicity guard | Earlier successful components plus GlobalSafari completed rollback never claim whole-Restore rollback | Deterministic model | PASS |
| 424 | Whole-Restore atomicity guard | Completed rollback message for GlobalSafari avoids no-change claims | Deterministic model | PASS |
| 425 | Message construction | Message case 1 uses expected outcome and required text | Deterministic model | PASS |
| 426 | Message construction | Message case 1 title equals mapper output | Deterministic model | PASS |
| 427 | Message construction | Message case 1 does not expose component failure domain/code | Deterministic model | PASS |
| 428 | Message construction | Message case 2 uses expected outcome and required text | Deterministic model | PASS |
| 429 | Message construction | Message case 2 title equals mapper output | Deterministic model | PASS |
| 430 | Message construction | Message case 2 does not expose component failure domain/code | Deterministic model | PASS |
| 431 | Message construction | Message case 3 uses expected outcome and required text | Deterministic model | PASS |
| 432 | Message construction | Message case 3 title equals mapper output | Deterministic model | PASS |
| 433 | Message construction | Message case 3 does not expose component failure domain/code | Deterministic model | PASS |
| 434 | Message construction | Message case 4 uses expected outcome and required text | Deterministic model | PASS |
| 435 | Message construction | Message case 4 title equals mapper output | Deterministic model | PASS |
| 436 | Message construction | Message case 4 does not expose component failure domain/code | Deterministic model | PASS |
| 437 | Message construction | Message case 5 uses expected outcome and required text | Deterministic model | PASS |
| 438 | Message construction | Message case 5 title equals mapper output | Deterministic model | PASS |
| 439 | Message construction | Message case 5 does not expose component failure domain/code | Deterministic model | PASS |
| 440 | Message construction | Message case 6 uses expected outcome and required text | Deterministic model | PASS |
| 441 | Message construction | Message case 6 title equals mapper output | Deterministic model | PASS |
| 442 | Message construction | Message case 6 does not expose component failure domain/code | Deterministic model | PASS |
| 443 | Message construction | Message case 7 uses expected outcome and required text | Deterministic model | PASS |
| 444 | Message construction | Message case 7 title equals mapper output | Deterministic model | PASS |
| 445 | Message construction | Message case 7 does not expose component failure domain/code | Deterministic model | PASS |
| 446 | Message construction | Message case 8 uses expected outcome and required text | Deterministic model | PASS |
| 447 | Message construction | Message case 8 title equals mapper output | Deterministic model | PASS |
| 448 | Message construction | Message case 8 does not expose component failure domain/code | Deterministic model | PASS |
| 449 | NSError fallback | Error value None resolves exact usable-description/fallback contract | Deterministic model | PASS |
| 450 | NSError fallback | Rollback-completed error value None prepends usable-description/fallback before explanation | Deterministic model | PASS |
| 451 | NSError fallback | Error value '' resolves exact usable-description/fallback contract | Deterministic model | PASS |
| 452 | NSError fallback | Rollback-completed error value '' prepends usable-description/fallback before explanation | Deterministic model | PASS |
| 453 | NSError fallback | Error value 'error one' resolves exact usable-description/fallback contract | Deterministic model | PASS |
| 454 | NSError fallback | Rollback-completed error value 'error one' prepends usable-description/fallback before explanation | Deterministic model | PASS |
| 455 | NSError fallback | Error value 'error two' resolves exact usable-description/fallback contract | Deterministic model | PASS |
| 456 | NSError fallback | Rollback-completed error value 'error two' prepends usable-description/fallback before explanation | Deterministic model | PASS |
| 457 | NSError fallback | Error value 'localized description' resolves exact usable-description/fallback contract | Deterministic model | PASS |
| 458 | NSError fallback | Rollback-completed error value 'localized description' prepends usable-description/fallback before explanation | Deterministic model | PASS |
| 459 | NSError fallback | Error value 'manifest failed' resolves exact usable-description/fallback contract | Deterministic model | PASS |
| 460 | NSError fallback | Rollback-completed error value 'manifest failed' prepends usable-description/fallback before explanation | Deterministic model | PASS |
| 461 | Background alert queue | Background outcome 1 queues exact title/message with nil path | Deterministic model | PASS |
| 462 | Background alert queue | Background outcome 1 clears pending fields after delivery without subtype downgrade | Deterministic model | PASS |
| 463 | Background alert queue | Background outcome 2 queues exact title/message with nil path | Deterministic model | PASS |
| 464 | Background alert queue | Background outcome 2 clears pending fields after delivery without subtype downgrade | Deterministic model | PASS |
| 465 | Background alert queue | Background outcome 3 queues exact title/message with nil path | Deterministic model | PASS |
| 466 | Background alert queue | Background outcome 3 clears pending fields after delivery without subtype downgrade | Deterministic model | PASS |
| 467 | Background alert queue | Background outcome 4 queues exact title/message with nil path | Deterministic model | PASS |
| 468 | Background alert queue | Background outcome 4 clears pending fields after delivery without subtype downgrade | Deterministic model | PASS |
| 469 | Background alert queue | Background outcome 5 queues exact title/message with nil path | Deterministic model | PASS |
| 470 | Background alert queue | Background outcome 5 clears pending fields after delivery without subtype downgrade | Deterministic model | PASS |
| 471 | Background alert queue | Background outcome 6 queues exact title/message with nil path | Deterministic model | PASS |
| 472 | Background alert queue | Background outcome 6 clears pending fields after delivery without subtype downgrade | Deterministic model | PASS |
| 473 | Backup TASK-5.1 zero-diff | Backup helper bytes | Protected region hash | PASS |
| 474 | Backup TASK-5.1 zero-diff | Backup helper hash | Protected region hash | PASS |
| 475 | Backup TASK-5.1 zero-diff | Pending region bytes | Protected region hash | PASS |
| 476 | Backup TASK-5.1 zero-diff | Pending region hash | Protected region hash | PASS |
| 477 | Backup TASK-5.1 zero-diff | Backup button bytes | Protected region hash | PASS |
| 478 | Backup TASK-5.1 zero-diff | Backup button hash | Protected region hash | PASS |
| 479 | Backup TASK-5.1 zero-diff | Backup Successful exact literal | Protected region hash | PASS |
| 480 | Backup TASK-5.1 zero-diff | Backup warning title exact literal | Protected region hash | PASS |
| 481 | Backup TASK-5.1 zero-diff | Backup Failed exact literal | Protected region hash | PASS |
| 482 | Backup TASK-5.1 zero-diff | Backup helper classifier remains present | Protected region hash | PASS |
| 483 | Backup TASK-5.1 zero-diff | Backup result validator remains present | Protected region hash | PASS |
| 484 | Backup TASK-5.1 zero-diff | Backup direct method remains one method | Protected region hash | PASS |
| 485 | ProjectX Restore caller zero-diff | ProjectX file size remains 372278 bytes | Hash/caller evidence | PASS |
| 486 | ProjectX Restore caller zero-diff | ProjectX hash remains baseline | Hash/caller evidence | PASS |
| 487 | ProjectX Restore caller zero-diff | ProjectX Restore caller count remains two | Hash/caller evidence | PASS |
| 488 | ProjectX Restore caller zero-diff | restoreQuickApps symbol remains present | Hash/caller evidence | PASS |
| 489 | ProjectX Restore caller zero-diff | restoreBackupDirectoryAfterClearingManifestApp symbol remains present | Hash/caller evidence | PASS |
| 490 | ProjectX Restore caller zero-diff | ProjectX has zero baseline diff | Hash/caller evidence | PASS |
| 491 | ProjectX Restore caller zero-diff | ProfileManager remains no direct restore caller | Hash/caller evidence | PASS |
| 492 | ProjectX Restore caller zero-diff | RRS source remains protected | Hash/caller evidence | PASS |
| 493 | ProjectX Restore caller zero-diff | Dashboard messaging remains protected | Hash/caller evidence | PASS |
| 494 | ProjectX Restore caller zero-diff | Respring behavior remains protected | Hash/caller evidence | PASS |
| 495 | Manager zero-diff | Manager size remains 239969 bytes | Hash/source evidence | PASS |
| 496 | Manager zero-diff | Manager hash remains baseline | Hash/source evidence | PASS |
| 497 | Manager zero-diff | Manager source has zero baseline diff | Hash/source evidence | PASS |
| 498 | Manager zero-diff | Pre-boundary nil-result completion remains protected | Hash/source evidence | PASS |
| 499 | Manager zero-diff | Post-boundary structured result assertion remains protected | Hash/source evidence | PASS |
| 500 | Manager zero-diff | Manager completion signature remains protected | Hash/source evidence | PASS |
| 501 | Manager zero-diff | Keychain warning-only semantics remain protected | Hash/source evidence | PASS |
| 502 | Manager zero-diff | Transaction execution remains protected | Hash/source evidence | PASS |
| 503 | Manager zero-diff | Rollback core remains protected | Hash/source evidence | PASS |
| 504 | Manager zero-diff | No manager presentation helper is added | Hash/source evidence | PASS |
| 505 | PXRestoreResult zero-diff | PXRestoreResult.h size remains 4512 bytes | Hash/source evidence | PASS |
| 506 | PXRestoreResult zero-diff | PXRestoreResult.h hash remains baseline | Hash/source evidence | PASS |
| 507 | PXRestoreResult zero-diff | PXRestoreResult.m size remains 15842 bytes | Hash/source evidence | PASS |
| 508 | PXRestoreResult zero-diff | PXRestoreResult.m hash remains baseline | Hash/source evidence | PASS |
| 509 | PXRestoreResult zero-diff | Result header has zero baseline diff | Hash/source evidence | PASS |
| 510 | PXRestoreResult zero-diff | Result implementation has zero baseline diff | Hash/source evidence | PASS |
| 511 | PXRestoreResult zero-diff | Eight component enum values remain present | Hash/source evidence | PASS |
| 512 | PXRestoreResult zero-diff | Three rollback statuses remain present | Hash/source evidence | PASS |
| 513 | PXRestoreResult zero-diff | Derived booleans remain readonly | Hash/source evidence | PASS |
| 514 | PXRestoreResult zero-diff | No duplicate presentation enum is added to result model | Hash/source evidence | PASS |
| 515 | Makefile zero-diff | Makefile size remains 9266 bytes | Hash evidence | PASS |
| 516 | Makefile zero-diff | Makefile hash remains baseline | Hash evidence | PASS |
| 517 | Makefile zero-diff | Makefile has zero baseline diff | Hash evidence | PASS |
| 518 | Makefile zero-diff | No test source is added to target | Hash evidence | PASS |
| 519 | Makefile zero-diff | Deployment target remains protected | Hash evidence | PASS |
| 520 | Makefile zero-diff | arm64 configuration remains protected | Hash evidence | PASS |
| 521 | Makefile zero-diff | arm64e configuration remains protected | Hash evidence | PASS |
| 522 | Makefile zero-diff | ARC configuration remains protected | Hash evidence | PASS |
| 523 | Line endings | Controller is UTF-8 decodable | Static source audit | PASS |
| 524 | Line endings | Controller has CRLF endings | Static source audit | PASS |
| 525 | Line endings | Controller has zero LF-only endings | Static source audit | PASS |
| 526 | Line endings | Controller has zero lone CR endings | Static source audit | PASS |
| 527 | Line endings | Controller has zero NUL bytes | Static source audit | PASS |
| 528 | Line endings | Controller has final newline | Static source audit | PASS |
| 529 | Line endings | No conflict markers are present | Static source audit | PASS |
| 530 | Line endings | No old Restore Complete exact literal remains | Static source audit | PASS |
| 531 | Line endings | Whole-controller errAlert count is zero | Static source audit | PASS |
| 532 | Line endings | Restore callback presenter count is one | Static source audit | PASS |
| 533 | Line endings | Restore callback copyPath:nil count is one | Static source audit | PASS |
| 534 | Line endings | No unknown success path remains | Static source audit | PASS |
| 535 | No TASK-5.3 work | No component status table is introduced | Static boundary audit | PASS |
| 536 | No TASK-5.3 work | No component names are rendered in callback | Static boundary audit | PASS |
| 537 | No TASK-5.3 work | No planned unit counts are rendered | Static boundary audit | PASS |
| 538 | No TASK-5.3 work | No committed unit counts are rendered | Static boundary audit | PASS |
| 539 | No TASK-5.3 work | No component failure domain is rendered | Static boundary audit | PASS |
| 540 | No TASK-5.3 work | No component failure code is rendered | Static boundary audit | PASS |
| 541 | No TASK-5.3 work | No component failure message list is rendered | Static boundary audit | PASS |
| 542 | No TASK-5.3 work | No rollback status list is rendered | Static boundary audit | PASS |
| 543 | No TASK-5.3 work | No skipped component list is rendered | Static boundary audit | PASS |
| 544 | No TASK-5.3 work | No not-attempted component list is rendered | Static boundary audit | PASS |
| 545 | No TASK-5.3 work | TASK-5.3 report is absent | Static boundary audit | PASS |
| 546 | No TASK-5.3 work | Only high-level outcome text is constructed | Static boundary audit | PASS |

## Objective-C/toolchain status
Windows static checks PASS: source literal counts, protected region/file hashes, caller counts, deterministic model, CRLF/NUL/conflict-marker audit, balanced delimiter audit, and git diff checks. Apple `make clean`, `make`, and `make package` were not run because Xcode/Theos/Apple SDK tooling is unavailable in this Windows workspace. No Apple compile/link/package PASS is claimed.

## Device/UI status
NOT RUN. No connected iOS device was available. Foreground/background and subtype preservation were validated by static source and deterministic state/message modeling only.

## Full authorized diff
```diff
diff --git a/AppDataBackupRestoreViewController.m b/AppDataBackupRestoreViewController.m
index 58dd27b..1de96d2 100644
--- a/AppDataBackupRestoreViewController.m
+++ b/AppDataBackupRestoreViewController.m
@@ -87,6 +87,277 @@ static NSString *PXBackupAlertTitleForOutcome(PXBackupAlertOutcome outcome) {
 @property (nonatomic, copy) NSString *pendingCopyPath;
 @end

+typedef NS_ENUM(NSUInteger, PXRestoreAlertOutcome) {
+    PXRestoreAlertOutcomeSuccessful = 1,
+    PXRestoreAlertOutcomeCompletedWithWarnings = 2,
+    PXRestoreAlertOutcomeCompletedWithComponentFailures = 3,
+    PXRestoreAlertOutcomeFailed = 4,
+    PXRestoreAlertOutcomeFailedWithCompletedRollback = 5,
+    PXRestoreAlertOutcomeFailedWithIncompleteRollback = 6,
+};
+
+static BOOL PXRestoreWarningArrayIsValidForPresentation(id value) {
+    if (![value isKindOfClass:[NSArray class]]) {
+        return NO;
+    }
+    for (id warning in (NSArray *)value) {
+        if (![warning isKindOfClass:[NSString class]] || [(NSString *)warning length] == 0) {
+            return NO;
+        }
+    }
+    return YES;
+}
+
+static BOOL PXRestoreComponentIsKnownSingleBitForPresentation(PXRestoreComponent component) {
+    NSUInteger value = (NSUInteger)component;
+    return value != 0 &&
+           (value & (value - 1)) == 0 &&
+           (value & ~(NSUInteger)PXRestoreComponentAll) == 0;
+}
+
+static BOOL PXRestoreRollbackStatusIsKnownForPresentation(PXRestoreRollbackStatus rollbackStatus) {
+    switch (rollbackStatus) {
+        case PXRestoreRollbackStatusNotPerformed:
+        case PXRestoreRollbackStatusCompleted:
+        case PXRestoreRollbackStatusIncomplete:
+            return YES;
+    }
+    return NO;
+}
+
+static BOOL PXRestoreResultIsValidForPresentation(PXRestoreResult *result) {
+    if (result == nil || [result class] != [PXRestoreResult class]) {
+        return NO;
+    }
+
+    id componentResultsValue = result.componentResults;
+    if (![componentResultsValue isKindOfClass:[NSArray class]] ||
+        [(NSArray *)componentResultsValue count] != 8) {
+        return NO;
+    }
+    if (!PXRestoreWarningArrayIsValidForPresentation(result.warnings)) {
+        return NO;
+    }
+
+    PXRestoreComponent requestedComponents = result.requestedComponents;
+    if (requestedComponents == 0 ||
+        ((NSUInteger)requestedComponents & ~(NSUInteger)PXRestoreComponentAll) != 0 ||
+        (requestedComponents & PXRestoreComponentApplicationData) == 0) {
+        return NO;
+    }
+
+    PXRestoreComponent observedSucceeded = 0;
+    PXRestoreComponent observedSkipped = 0;
+    PXRestoreComponent observedNotAttempted = 0;
+    PXRestoreComponent observedFailed = 0;
+    PXRestoreComponent seenComponents = 0;
+    BOOL observedIncompleteRollback = NO;
+
+    for (id value in (NSArray *)componentResultsValue) {
+        if ([value class] != [PXRestoreComponentResult class]) {
+            return NO;
+        }
+        PXRestoreComponentResult *componentResult = value;
+        PXRestoreComponent component = componentResult.component;
+        if (!PXRestoreComponentIsKnownSingleBitForPresentation(component) ||
+            (seenComponents & component) != 0) {
+            return NO;
+        }
+        seenComponents |= component;
+
+        if (!PXRestoreWarningArrayIsValidForPresentation(componentResult.warnings)) {
+            return NO;
+        }
+        id failure = componentResult.failure;
+        if (failure != nil && [failure class] != [PXRestoreFailure class]) {
+            return NO;
+        }
+
+        BOOL requested = (requestedComponents & component) != 0;
+        switch (componentResult.status) {
+            case PXRestoreComponentStatusSkipped:
+                if (requested ||
+                    componentResult.plannedUnitCount != 0 ||
+                    componentResult.committedUnitCount != 0 ||
+                    componentResult.rollbackStatus != PXRestoreRollbackStatusNotPerformed ||
+                    componentResult.warnings.count != 0 ||
+                    failure != nil) {
+                    return NO;
+                }
+                observedSkipped |= component;
+                break;
+
+            case PXRestoreComponentStatusNotAttempted:
+                if (!requested ||
+                    componentResult.plannedUnitCount < 1 ||
+                    componentResult.committedUnitCount != 0 ||
+                    componentResult.rollbackStatus != PXRestoreRollbackStatusNotPerformed ||
+                    failure != nil) {
+                    return NO;
+                }
+                observedNotAttempted |= component;
+                break;
+
+            case PXRestoreComponentStatusSucceeded:
+                if (!requested ||
+                    componentResult.plannedUnitCount < 1 ||
+                    componentResult.committedUnitCount != componentResult.plannedUnitCount ||
+                    componentResult.rollbackStatus != PXRestoreRollbackStatusNotPerformed ||
+                    failure != nil) {
+                    return NO;
+                }
+                observedSucceeded |= component;
+                break;
+
+            case PXRestoreComponentStatusFailed:
+                if (!requested ||
+                    componentResult.plannedUnitCount < 1 ||
+                    componentResult.committedUnitCount != 0 ||
+                    failure == nil ||
+                    !PXRestoreRollbackStatusIsKnownForPresentation(componentResult.rollbackStatus)) {
+                    return NO;
+                }
+                observedFailed |= component;
+                if (componentResult.rollbackStatus == PXRestoreRollbackStatusIncomplete) {
+                    observedIncompleteRollback = YES;
+                }
+                break;
+
+            default:
+                return NO;
+        }
+    }
+
+    if (seenComponents != PXRestoreComponentAll) {
+        return NO;
+    }
+
+    PXRestoreComponent succeededComponents = result.succeededComponents;
+    PXRestoreComponent skippedComponents = result.skippedComponents;
+    PXRestoreComponent notAttemptedComponents = result.notAttemptedComponents;
+    PXRestoreComponent failedComponents = result.failedComponents;
+    PXRestoreComponent aggregateUnion =
+        succeededComponents |
+        skippedComponents |
+        notAttemptedComponents |
+        failedComponents;
+    BOOL masksAreKnown =
+        (((NSUInteger)succeededComponents & ~(NSUInteger)PXRestoreComponentAll) == 0) &&
+        (((NSUInteger)skippedComponents & ~(NSUInteger)PXRestoreComponentAll) == 0) &&
+        (((NSUInteger)notAttemptedComponents & ~(NSUInteger)PXRestoreComponentAll) == 0) &&
+        (((NSUInteger)failedComponents & ~(NSUInteger)PXRestoreComponentAll) == 0);
+    BOOL masksAreDisjoint =
+        (succeededComponents & skippedComponents) == 0 &&
+        (succeededComponents & notAttemptedComponents) == 0 &&
+        (succeededComponents & failedComponents) == 0 &&
+        (skippedComponents & notAttemptedComponents) == 0 &&
+        (skippedComponents & failedComponents) == 0 &&
+        (notAttemptedComponents & failedComponents) == 0;
+    PXRestoreComponent expectedSkipped =
+        (PXRestoreComponent)((NSUInteger)PXRestoreComponentAll &
+                             ~(NSUInteger)requestedComponents);
+
+    if (!masksAreKnown ||
+        !masksAreDisjoint ||
+        aggregateUnion != PXRestoreComponentAll ||
+        succeededComponents != observedSucceeded ||
+        skippedComponents != observedSkipped ||
+        notAttemptedComponents != observedNotAttempted ||
+        failedComponents != observedFailed ||
+        requestedComponents != (succeededComponents |
+                                notAttemptedComponents |
+                                failedComponents) ||
+        skippedComponents != expectedSkipped) {
+        return NO;
+    }
+
+    if (result.hasWarnings != (result.warnings.count > 0) ||
+        result.hasFailures != (failedComponents != 0) ||
+        result.hasIncompleteRollback != observedIncompleteRollback ||
+        result.allRequestedComponentsSucceeded !=
+            (succeededComponents == requestedComponents)) {
+        return NO;
+    }
+
+    return YES;
+}
+
+static BOOL PXRestoreResultHasCompletedRollback(PXRestoreResult *result) {
+    for (PXRestoreComponentResult *componentResult in result.componentResults) {
+        if (componentResult.status == PXRestoreComponentStatusFailed &&
+            componentResult.rollbackStatus == PXRestoreRollbackStatusCompleted) {
+            return YES;
+        }
+    }
+    return NO;
+}
+
+static BOOL PXRestoreResultHasIncompleteRollback(PXRestoreResult *result) {
+    for (PXRestoreComponentResult *componentResult in result.componentResults) {
+        if (componentResult.status == PXRestoreComponentStatusFailed &&
+            componentResult.rollbackStatus == PXRestoreRollbackStatusIncomplete) {
+            return YES;
+        }
+    }
+    return NO;
+}
+
+static PXRestoreAlertOutcome PXRestoreAlertOutcomeForResult(PXRestoreResult *result,
+                                                             NSError *error) {
+    BOOL validResult = PXRestoreResultIsValidForPresentation(result);
+    if (validResult && PXRestoreResultHasIncompleteRollback(result)) {
+        return PXRestoreAlertOutcomeFailedWithIncompleteRollback;
+    }
+    if (validResult && PXRestoreResultHasCompletedRollback(result)) {
+        return PXRestoreAlertOutcomeFailedWithCompletedRollback;
+    }
+    if (error != nil) {
+        return PXRestoreAlertOutcomeFailed;
+    }
+    if (!validResult) {
+        return PXRestoreAlertOutcomeFailed;
+    }
+    if (result.hasFailures) {
+        return PXRestoreAlertOutcomeCompletedWithComponentFailures;
+    }
+    if (!result.allRequestedComponentsSucceeded) {
+        return PXRestoreAlertOutcomeFailed;
+    }
+    if (result.hasWarnings) {
+        return PXRestoreAlertOutcomeCompletedWithWarnings;
+    }
+    return PXRestoreAlertOutcomeSuccessful;
+}
+
+static NSString *PXRestoreAlertTitleForOutcome(PXRestoreAlertOutcome outcome) {
+    switch (outcome) {
+        case PXRestoreAlertOutcomeSuccessful:
+            return @"Restore Successful";
+        case PXRestoreAlertOutcomeCompletedWithWarnings:
+            return @"Restore Completed with Warnings";
+        case PXRestoreAlertOutcomeCompletedWithComponentFailures:
+            return @"Restore Completed with Component Failures";
+        case PXRestoreAlertOutcomeFailedWithCompletedRollback:
+            return @"Restore Failed: Component Rollback Completed";
+        case PXRestoreAlertOutcomeFailedWithIncompleteRollback:
+            return @"Restore Failed: Rollback Incomplete";
+        case PXRestoreAlertOutcomeFailed:
+        default:
+            return @"Restore Failed";
+    }
+}
+
+static void PXAppendRestoreWarnings(NSMutableString *message,
+                                    NSArray<NSString *> *warnings) {
+    if (warnings.count == 0) {
+        return;
+    }
+    [message appendString:@"\n\nWarnings:\n"];
+    for (NSString *warning in warnings) {
+        [message appendFormat:@"- %@\n", warning];
+    }
+}
+
 @implementation AppDataBackupRestoreViewController

 static void PXAttemptBringProjectXToFront(void) {
@@ -566,26 +837,61 @@ static void PXAttemptBringProjectXToFront(void) {
                                                                  appName:self.appName
                                                               completion:^(PXRestoreResult *result, NSError *error) {
                      [processingAlert dismissViewControllerAnimated:YES completion:^{
-                         if (error) {
-                             UIAlertController *errAlert = [UIAlertController alertControllerWithTitle:@"Restore Failed"
-                                                                                              message:error.localizedDescription ?: @"Unknown error"
-                                                                                       preferredStyle:UIAlertControllerStyleAlert];
-                             [errAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
-                             [self _presentResultAlertBestEffortWithTitle:@"Restore Failed"
-                                                                 message:error.localizedDescription ?: @"Unknown error"
-                                                                copyPath:nil];
-                             return;
+                         BOOL validResult = PXRestoreResultIsValidForPresentation(result);
+                         PXRestoreAlertOutcome outcome = PXRestoreAlertOutcomeForResult(result, error);
+                         NSString *title = PXRestoreAlertTitleForOutcome(outcome);
+                         NSMutableString *message = nil;
+
+                         NSString *errorDescription = nil;
+                         if ([error isKindOfClass:[NSError class]]) {
+                             id localizedDescription = [(NSError *)error localizedDescription];
+                             if ([localizedDescription isKindOfClass:[NSString class]] &&
+                                 [(NSString *)localizedDescription length] > 0) {
+                                 errorDescription = localizedDescription;
+                             }
+                         }
+                         NSString *failureMessage =
+                             errorDescription ?: @"Restore failed without a valid result.";
+
+                         switch (outcome) {
+                             case PXRestoreAlertOutcomeSuccessful:
+                             case PXRestoreAlertOutcomeCompletedWithWarnings:
+                                 message = [NSMutableString stringWithFormat:
+                                     @"Data for %@ has been restored.",
+                                     appIdentifier];
+                                 break;
+
+                             case PXRestoreAlertOutcomeCompletedWithComponentFailures:
+                                 message = [NSMutableString stringWithFormat:
+                                     @"Restore processing for %@ completed, but one or more requested components failed.",
+                                     appIdentifier];
+                                 break;
+
+                             case PXRestoreAlertOutcomeFailedWithCompletedRollback:
+                                 message = [NSMutableString stringWithString:failureMessage];
+                                 [message appendString:
+                                     @"\n\nThe failed component reported a completed rollback. Components restored earlier were not rolled back."];
+                                 break;
+
+                             case PXRestoreAlertOutcomeFailedWithIncompleteRollback:
+                                 message = [NSMutableString stringWithString:failureMessage];
+                                 [message appendString:
+                                     @"\n\nRollback did not complete safely. Some data may remain changed."];
+                                 break;
+
+                             case PXRestoreAlertOutcomeFailed:
+                             default:
+                                 message = [NSMutableString stringWithString:failureMessage];
+                                 break;
                          }

-                        NSMutableString *msg = [NSMutableString stringWithFormat:@"Data for %@ has been restored.", appIdentifier];
-                        if (result.warnings.count) {
-                            [msg appendString:@"\n\nWarnings:\n"];
-                            for (NSString *w in result.warnings) {
-                                [msg appendFormat:@"- %@\n", w];
-                            }
-                        }
+                         if (validResult && result.warnings.count > 0) {
+                             PXAppendRestoreWarnings(message, result.warnings);
+                         }

-                         [self _presentResultAlertBestEffortWithTitle:@"Restore Complete" message:msg copyPath:nil];
+                         [self _presentResultAlertBestEffortWithTitle:title
+                                                             message:message
+                                                            copyPath:nil];
                      }];
                  }];
              }]];
```

The implementation commit is restricted to the modified controller and this added report.

## Line-ending/NUL audit
- Controller: UTF-8 CRLF, 911 CRLF endings, zero LF-only endings, zero lone CR, zero NUL, final newline.
- TASK-5.2 report: UTF-8 LF, zero CRLF, zero NUL, final newline.
- No broad formatting, controller encoding conversion, or unrelated whitespace cleanup.

## Residual risks
Apple compiler/linker/package validation and physical-device UI execution remain pending. Presentation validity intentionally duplicates immutable-result coherence checks at the UI boundary to fail closed against anomalous callbacks; it does not alter execution or rollback core.

## TASK-5.3 boundary
TASK-5.3 was not started. No component name/status/count/failure/rollback list is displayed, and no component-level result UI or public API was added.

GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
