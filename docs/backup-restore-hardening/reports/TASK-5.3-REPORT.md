# TASK-5.3 Implementation Report

## Result
IMPLEMENTED. The direct Restore result alert now appends a complete canonical section for all eight immutable Restore components whenever the TASK-5.2 presentation validator accepts the result. The six TASK-5.2 outcomes, titles, classifier, primary messages, aggregate warning behavior, pending queue, manager/core execution, and batch callers remain unchanged.

## User authority
The current request explicitly unlocks TASK-5.3 despite the coordinator roadmap lock. TASK-5.2 is user-authority PASSED and COMPLETED. TASK-5.4 is outside this implementation.

## TASK-5.2 review-file status
`docs/backup-restore-hardening/reviews/TASK-5.2-REVIEW.md` is absent. The task specification declares the missing review non-blocking because the user directly confirmed TASK-5.2 completion and opened TASK-5.3.

## Baseline
- Required baseline: `e5d9c090a62740a354386b9694fe0a5d83e869ab`
- Expected HEAD: `e5d9c09 phase5(task-5.2): distinguish restore rollback outcomes`
- Baseline matched before implementation.

## Working-tree preservation
Pre-existing coordinator changes in `STATUS.md`, `ROADMAP.md`, `DECISIONS.md`, and `README.md`, plus all pre-existing untracked task/review documents, were not staged, reset, deleted, rewritten, or normalized.

## Exact authorized scope
- `M AppDataBackupRestoreViewController.m`
- `A docs/backup-restore-hardening/reports/TASK-5.3-REPORT.md`
- No controller header, public model, manager/core, transaction, ProjectX caller, Keychain, Makefile, or coordinator mutation.

## Existing direct/batch caller inventory
| Production caller file | Count | Ownership |
|---|---:|---|
| `AppDataBackupRestoreViewController.m` | 1 | Direct Restore result alert |
| `ProjectXViewController.m` | 2 | Quick Restore and RRS/batch workflows |
| `ProfileManagerViewController.m` | 0 | No direct Restore caller |

## Current component-display gap
TASK-5.2 classified the high-level Restore outcome and built one final alert message, but did not show component names, statuses, unit progress, rollback labels, component warning attribution, or immutable component failure messages. TASK-5.3 adds only this missing section.

## Valid-result authority
The formatter runs only after `PXRestoreResultIsValidForPresentation(result)` returns YES. It reads only immutable `PXRestoreResult`, `PXRestoreComponentResult`, and `PXRestoreFailure.message` fields. Invalid or pre-boundary results produce no synthetic or partial component section.

## Exact canonical component order
1. Application Data
2. Profile App Data
3. Global Safari
4. App Groups
5. System Global
6. Shared System Databases
7. Preferences
8. Keychain

Incoming `componentResults` array order is never display authority. Every entry is looked up through `componentResultForComponent:` using the private canonical order.

## Exact component display names
| Component | Display name |
|---|---|
| `1` | `Application Data` |
| `2` | `Profile App Data` |
| `4` | `Global Safari` |
| `8` | `App Groups` |
| `16` | `System Global` |
| `32` | `Shared System Databases` |
| `64` | `Preferences` |
| `128` | `Keychain` |
Unknown, zero, combined, all-mask, high-bit, and signed-cast values map to nil.

## Exact status labels
| Status | Label |
|---|---|
| `0` | `Skipped` |
| `1` | `Not Attempted` |
| `2` | `Succeeded` |
| `3` | `Failed` |
Skipped and Not Attempted remain distinct.

## Exact rollback labels
| Rollback status | Label |
|---|---|
| `0` | `Rollback Not Performed` |
| `1` | `Rollback Completed` |
| `2` | `Rollback Incomplete` |
Rollback labels are emitted only for Failed components.

## Unit singular/plural contract
`plannedUnitCount == 1` uses `<committed>/<planned> unit`; every other planned count uses `<committed>/<planned> units`. Skipped components omit progress entirely.

## Warning singular/plural contract
Zero component warnings produce no suffix, one produces `1 warning`, and any other count produces `<N> warnings`. Component warning strings are not copied into component lines.

## Skipped line contract
Exact shape: `- <Component Name>: Skipped`. No parentheses, progress, warning count, rollback label, or failure detail is displayed.

## NotAttempted line contract
Exact shape: `- <Component Name>: Not Attempted (<unit progress>)`, with optional `; <warning count>` inside the same parentheses.

## Succeeded line contract
Exact shape: `- <Component Name>: Succeeded (<unit progress>)`, with optional `; <warning count>`.

## Failed line contract
Exact shape: `- <Component Name>: Failed (<unit progress>; <rollback label>)`, followed by optional warning count after the rollback label.

## Failure-message contract
Every Failed component receives an immediate next line: `  Failure: <PXRestoreFailure.message>`. The message is preserved exactly, including punctuation, newlines, and UTF-8. Domain, code, NSError userInfo, stack traces, and debug fields are not displayed.

## Complete section format
The formatter returns one string beginning with exact prefix `\n\nComponent Results:\n`, followed by exactly eight component bullet lines in canonical order. Failure detail lines are not component bullets. No partial section is returned.

## Canonical lookup/order proof
128 deterministic, unique input permutations were rendered. Every output ordered Application Data through Keychain identically and contained each display name exactly once.

## All-eight-component proof
Every valid modeled result produced exactly eight lines beginning with `- `. Removing any of the eight components or replacing one with an unknown component caused the temporary section builder to return nil.

## No partial section proof
The builder accumulates entries privately and returns only after all eight mappings, lookups, statuses, rollback labels, and failure messages succeed. A failed lookup never leaks a seven-line or otherwise partial section.

## Primary-message placement
The protected TASK-5.2 primary message and rollback explanation are built first. The component section is appended afterward without modifying the switch.

## Aggregate-warning placement
The unchanged `PXAppendRestoreWarnings` call remains after the component append. Exact final order is primary message, rollback explanation when applicable, Component Results, then aggregate Warnings.

## Warning nonduplication proof
Component lines display only warning counts. Component warning strings are never iterated. Aggregate warning strings remain rendered exactly once by the existing helper, preserving order and duplicates.

## Six-outcome integration
| TASK-5.2 outcome | Component section | Aggregate warnings |
|---|---|---|
| Restore Successful | Present for valid result | Absent when empty |
| Restore Completed with Warnings | Present | Present after components |
| Restore Completed with Component Failures | Present | Present when aggregate warnings exist |
| Restore Failed | Present only for valid structured result | Present only from valid result |
| Restore Failed: Component Rollback Completed | Present | Present after rollback explanation and components |
| Restore Failed: Rollback Incomplete | Present | Present after safety explanation and components |

## Pre-boundary failure behavior
`result == nil && error != nil` retains title `Restore Failed` and the usable NSError description/fallback. It displays no Component Results section, no synthetic Not Attempted rows, and no Restore Copy Path.

## Invalid callback behavior
Nil, malformed, incomplete-coverage, invalid-mask, invalid-rollback, or otherwise rejected results retain TASK-5.2 fail-closed presentation. No result fields are read for component display after validation fails.

## Keychain warning-only behavior
A valid Keychain warning-only compatibility result continues to use `Restore Completed with Component Failures`. Its Keychain line is Failed with `Rollback Not Performed`, component warning count, and immutable failure message; aggregate warning text remains below the section.

## Rollback completed behavior
The existing high-level title and whole-Restore atomicity disclaimer remain unchanged. The failed component line adds `Rollback Completed`; previously committed components continue to appear with their own statuses.

## Rollback incomplete behavior
The existing highest-safety title and message remain unchanged. The failed component line adds `Rollback Incomplete`; the section cannot downgrade this state to warning or ordinary component failure.

## Pending/background behavior
The pending region remains byte-identical. The complete final string snapshot—including all eight component lines, failure details, and aggregate warnings—is stored in `pendingAlertMessage`; `pendingCopyPath` remains nil and become-active delivery does not rebuild the section.

## TASK-5.1 protected region hashes
| Region | Bytes | SHA-256 | Unchanged |
|---|---:|---|---|
| `backup-presentation-helpers` | 1907 | `eec90ebe21381e18fb5f62579aa90163ee850f544fb46d08e78f15a853366335` | TRUE |
| `backup-button-method` | 4054 | `a2ab9df97202e358ecd1a92a2f06735ae11707ed21a9b170dbd1935798078a6e` | TRUE |
| `pending-alert-region` | 2754 | `00ba8cbbe9952292f0d9d39e0d3db7c4869b4968e3455527d373c8d503d48337` | TRUE |

## TASK-5.2 outcome-core hash
`restore-outcome-core`: 10510 bytes, SHA-256 `7b58e3b703dcea3d0ffb44120c65d18591420810bb833804537e3a0a91227a22`, byte-identical.

## TASK-5.2 warning-helper hash
`restore-warning-helper`: 344 bytes, SHA-256 `bee9a0b8976adb067044fec0059d897b2e5ba9b98a17da9860073be0f1c99a34`, byte-identical.

## TASK-5.2 primary-message hash
`restore-primary-message-switch`: 1919 bytes, SHA-256 `09c43105961572ba7bac43c38c097697ce0de9849e3eb6245c32a09c27ff859b`, byte-identical.

## Manager/model hashes
- `AppDataBackupManager.h`: 1442 bytes, `b19c1c61e6df642468d713dede5a0c0bd0dbb6a0ac72d98ad6878d3cae1f2e75`
- `AppDataBackupManager.m`: 239969 bytes, `61fc1ff901d64a0b2732c1ea44f47f23209a0b55404fbc69e27889ee03939028`
- `PXRestoreResult.h`: 4512 bytes, `cb7f2f3e40b3414d329405b1802bf6a9f245f1b660ca983d04776c0af449e69d`
- `PXRestoreResult.m`: 15842 bytes, `c698a854589731f0987379c324d02729f3b586fd0ac3575f9798b77d6207c2fb`

## ProjectX caller hash
`ProjectXViewController.m`: 372278 bytes, SHA-256 `b7c5293dfa5d27fdc39c36f236f76306a855eaaf4e9e028f4c2111eb68146162`, with both batch Restore callers unchanged.

## Makefile hash
`Makefile`: 9266 bytes, SHA-256 `b2d9ca1083f85b818f132612e792c73e94e78390ef06092db2075439af945dfa`, zero diff.

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
| Eight exact component display-name literals | PASS: one each |
| Four exact status literals | PASS: one each |
| Three exact rollback literals | PASS: one each |
| Exact `Component Results:` literal | PASS: one |
| Exact failure-detail format literal | PASS: one |
| Canonical component array entries | PASS: eight |
| Formatter `componentResultForComponent:` calls | PASS: one |
| Restore callback component-section calls | PASS: one |
| Restore callback component append calls | PASS: one |
| Aggregate warning helper callback calls | PASS: one |
| Restore presenter calls | PASS: one |
| Restore `copyPath:nil` | PASS: one |
| New direct callback UIAlertController declarations | PASS: zero |
| Component warning-string iteration | PASS: zero |
| Failure domain/code display | PASS: zero |
| Six TASK-5.2 title literals | PASS: one each |
| Old `Restore Complete` literal | PASS: zero |
| Three TASK-5.1 backup titles | PASS: one each |

## Deterministic formatter tests
The temporary external model verified exact names, unknown-value rejection, four statuses, three rollback labels, unit singular/plural, warning singular/plural, every Skipped line, 192 NotAttempted/Succeeded combinations, 192 Failed combinations, failure-message fidelity, warning-string nonduplication, no-partial-section behavior, and message placement. Temporary model files were deleted after execution.

## 128 permutation results
128 deterministic unique input permutations passed. Every output contained exactly eight component bullets in the same canonical order, and each exact component display name appeared once.

## Explicit scenarios
Explicit numbered scenario count: 672.

| # | Group | Scenario | Evidence | Status |
|---:|---|---|---|---|
| 1 | Baseline and scope | HEAD matched required baseline e5d9c090a62740a354386b9694fe0a5d83e869ab | Repository/source inventory | PASS |
| 2 | Baseline and scope | Expected baseline subject is phase5(task-5.2): distinguish restore rollback outcomes | Repository/source inventory | PASS |
| 3 | Baseline and scope | TASK-5.2 user authority is PASSED | Repository/source inventory | PASS |
| 4 | Baseline and scope | TASK-5.2 user authority is COMPLETED | Repository/source inventory | PASS |
| 5 | Baseline and scope | TASK-5.2 review file is absent and explicitly non-blocking | Repository/source inventory | PASS |
| 6 | Baseline and scope | Roadmap lock is overridden only by current user authority | Repository/source inventory | PASS |
| 7 | Baseline and scope | Authorized source file is AppDataBackupRestoreViewController.m | Repository/source inventory | PASS |
| 8 | Baseline and scope | Authorized report file is TASK-5.3-REPORT.md | Repository/source inventory | PASS |
| 9 | Baseline and scope | Controller header remains protected | Repository/source inventory | PASS |
| 10 | Baseline and scope | No production source file is added | Repository/source inventory | PASS |
| 11 | Baseline and scope | No public presentation model is added | Repository/source inventory | PASS |
| 12 | Baseline and scope | Makefile remains protected | Repository/source inventory | PASS |
| 13 | Baseline and scope | Direct Restore caller count is one | Repository/source inventory | PASS |
| 14 | Baseline and scope | ProjectX Restore caller count is two | Repository/source inventory | PASS |
| 15 | Baseline and scope | ProfileManager direct Restore caller count is zero | Repository/source inventory | PASS |
| 16 | Baseline and scope | Component section is limited to valid structured result | Repository/source inventory | PASS |
| 17 | Baseline and scope | Existing direct result alert remains the presentation surface | Repository/source inventory | PASS |
| 18 | Baseline and scope | No second alert or alert action is introduced | Repository/source inventory | PASS |
| 19 | Baseline and scope | Coordinator documents remain outside implementation scope | Repository/source inventory | PASS |
| 20 | Baseline and scope | Pre-existing task and review files remain preserved | Repository/source inventory | PASS |
| 21 | Baseline and scope | TASK-5.4 advanced-scope confirmation is not started | Repository/source inventory | PASS |
| 22 | Baseline and scope | No push is performed | Repository/source inventory | PASS |
| 23 | Baseline and scope | Controller baseline uses UTF-8 CRLF | Repository/source inventory | PASS |
| 24 | Baseline and scope | Report uses UTF-8 LF | Repository/source inventory | PASS |
| 25 | Component names | Known component value 1 maps exactly to Application Data | Deterministic model | PASS |
| 26 | Component names | Known component value 2 maps exactly to Profile App Data | Deterministic model | PASS |
| 27 | Component names | Known component value 4 maps exactly to Global Safari | Deterministic model | PASS |
| 28 | Component names | Known component value 8 maps exactly to App Groups | Deterministic model | PASS |
| 29 | Component names | Known component value 16 maps exactly to System Global | Deterministic model | PASS |
| 30 | Component names | Known component value 32 maps exactly to Shared System Databases | Deterministic model | PASS |
| 31 | Component names | Known component value 64 maps exactly to Preferences | Deterministic model | PASS |
| 32 | Component names | Known component value 128 maps exactly to Keychain | Deterministic model | PASS |
| 33 | Unknown component values | Component value 0 has no display name and fails closed | Deterministic model | PASS |
| 34 | Unknown component values | Component value 3 has no display name and fails closed | Deterministic model | PASS |
| 35 | Unknown component values | Component value 5 has no display name and fails closed | Deterministic model | PASS |
| 36 | Unknown component values | Component value 255 has no display name and fails closed | Deterministic model | PASS |
| 37 | Unknown component values | Component value 256 has no display name and fails closed | Deterministic model | PASS |
| 38 | Unknown component values | Component value -1 has no display name and fails closed | Deterministic model | PASS |
| 39 | Unknown component values | Component value 2147483648 has no display name and fails closed | Deterministic model | PASS |
| 40 | Unknown component values | Component value 129 has no display name and fails closed | Deterministic model | PASS |
| 41 | Unknown component values | Component value 65535 has no display name and fails closed | Deterministic model | PASS |
| 42 | Unknown component values | Component value 6 has no display name and fails closed | Deterministic model | PASS |
| 43 | Unknown component values | Component value 12 has no display name and fails closed | Deterministic model | PASS |
| 44 | Unknown component values | Component value 192 has no display name and fails closed | Deterministic model | PASS |
| 45 | Status labels | Status 0 maps exactly to Skipped | Deterministic model | PASS |
| 46 | Status labels | Status 1 maps exactly to Not Attempted | Deterministic model | PASS |
| 47 | Status labels | Status 2 maps exactly to Succeeded | Deterministic model | PASS |
| 48 | Status labels | Status 3 maps exactly to Failed | Deterministic model | PASS |
| 49 | Status labels | Unknown status -1 maps to nil | Deterministic model | PASS |
| 50 | Status labels | Unknown status 4 maps to nil | Deterministic model | PASS |
| 51 | Status labels | Unknown status 99 maps to nil | Deterministic model | PASS |
| 52 | Status labels | Unknown status 2147483647 maps to nil | Deterministic model | PASS |
| 53 | Rollback labels | Rollback status 0 maps exactly to Rollback Not Performed | Deterministic model | PASS |
| 54 | Rollback labels | Rollback status 1 maps exactly to Rollback Completed | Deterministic model | PASS |
| 55 | Rollback labels | Rollback status 2 maps exactly to Rollback Incomplete | Deterministic model | PASS |
| 56 | Rollback labels | Unknown rollback status -1 maps to nil | Deterministic model | PASS |
| 57 | Rollback labels | Unknown rollback status 3 maps to nil | Deterministic model | PASS |
| 58 | Rollback labels | Unknown rollback status 99 maps to nil | Deterministic model | PASS |
| 59 | Unit formatting | Committed/planned 0/1 formats as 0/1 unit | Deterministic model | PASS |
| 60 | Unit formatting | Committed/planned 1/1 formats as 1/1 unit | Deterministic model | PASS |
| 61 | Unit formatting | Committed/planned 2/1 formats as 2/1 unit | Deterministic model | PASS |
| 62 | Unit formatting | Committed/planned 4096/1 formats as 4096/1 unit | Deterministic model | PASS |
| 63 | Unit formatting | Committed/planned 0/2 formats as 0/2 units | Deterministic model | PASS |
| 64 | Unit formatting | Committed/planned 1/2 formats as 1/2 units | Deterministic model | PASS |
| 65 | Unit formatting | Committed/planned 2/2 formats as 2/2 units | Deterministic model | PASS |
| 66 | Unit formatting | Committed/planned 4096/2 formats as 4096/2 units | Deterministic model | PASS |
| 67 | Unit formatting | Committed/planned 0/4096 formats as 0/4096 units | Deterministic model | PASS |
| 68 | Unit formatting | Committed/planned 1/4096 formats as 1/4096 units | Deterministic model | PASS |
| 69 | Unit formatting | Committed/planned 2/4096 formats as 2/4096 units | Deterministic model | PASS |
| 70 | Unit formatting | Committed/planned 4096/4096 formats as 4096/4096 units | Deterministic model | PASS |
| 71 | Warning-count formatting | Component warning count 0 formats as None | Deterministic model | PASS |
| 72 | Warning-count formatting | Component warning count 1 formats as '1 warning' | Deterministic model | PASS |
| 73 | Warning-count formatting | Component warning count 2 formats as '2 warnings' | Deterministic model | PASS |
| 74 | Warning-count formatting | Component warning count 4096 formats as '4096 warnings' | Deterministic model | PASS |
| 75 | Skipped formatting | Application Data Skipped line has no progress, warnings, rollback, or failure detail | Deterministic model | PASS |
| 76 | Skipped formatting | Profile App Data Skipped line has no progress, warnings, rollback, or failure detail | Deterministic model | PASS |
| 77 | Skipped formatting | Global Safari Skipped line has no progress, warnings, rollback, or failure detail | Deterministic model | PASS |
| 78 | Skipped formatting | App Groups Skipped line has no progress, warnings, rollback, or failure detail | Deterministic model | PASS |
| 79 | Skipped formatting | System Global Skipped line has no progress, warnings, rollback, or failure detail | Deterministic model | PASS |
| 80 | Skipped formatting | Shared System Databases Skipped line has no progress, warnings, rollback, or failure detail | Deterministic model | PASS |
| 81 | Skipped formatting | Preferences Skipped line has no progress, warnings, rollback, or failure detail | Deterministic model | PASS |
| 82 | Skipped formatting | Keychain Skipped line has no progress, warnings, rollback, or failure detail | Deterministic model | PASS |
| 83 | Not Attempted formatting | Application Data Not Attempted planned=1 warnings=0 preserves exact punctuation and plurality | Deterministic model | PASS |
| 84 | Not Attempted formatting | Application Data Not Attempted planned=1 warnings=1 preserves exact punctuation and plurality | Deterministic model | PASS |
| 85 | Not Attempted formatting | Application Data Not Attempted planned=1 warnings=2 preserves exact punctuation and plurality | Deterministic model | PASS |
| 86 | Not Attempted formatting | Application Data Not Attempted planned=1 warnings=4096 preserves exact punctuation and plurality | Deterministic model | PASS |
| 87 | Not Attempted formatting | Application Data Not Attempted planned=2 warnings=0 preserves exact punctuation and plurality | Deterministic model | PASS |
| 88 | Not Attempted formatting | Application Data Not Attempted planned=2 warnings=1 preserves exact punctuation and plurality | Deterministic model | PASS |
| 89 | Not Attempted formatting | Application Data Not Attempted planned=2 warnings=2 preserves exact punctuation and plurality | Deterministic model | PASS |
| 90 | Not Attempted formatting | Application Data Not Attempted planned=2 warnings=4096 preserves exact punctuation and plurality | Deterministic model | PASS |
| 91 | Not Attempted formatting | Application Data Not Attempted planned=4096 warnings=0 preserves exact punctuation and plurality | Deterministic model | PASS |
| 92 | Not Attempted formatting | Application Data Not Attempted planned=4096 warnings=1 preserves exact punctuation and plurality | Deterministic model | PASS |
| 93 | Not Attempted formatting | Application Data Not Attempted planned=4096 warnings=2 preserves exact punctuation and plurality | Deterministic model | PASS |
| 94 | Not Attempted formatting | Application Data Not Attempted planned=4096 warnings=4096 preserves exact punctuation and plurality | Deterministic model | PASS |
| 95 | Not Attempted formatting | Profile App Data Not Attempted planned=1 warnings=0 preserves exact punctuation and plurality | Deterministic model | PASS |
| 96 | Not Attempted formatting | Profile App Data Not Attempted planned=1 warnings=1 preserves exact punctuation and plurality | Deterministic model | PASS |
| 97 | Not Attempted formatting | Profile App Data Not Attempted planned=1 warnings=2 preserves exact punctuation and plurality | Deterministic model | PASS |
| 98 | Not Attempted formatting | Profile App Data Not Attempted planned=1 warnings=4096 preserves exact punctuation and plurality | Deterministic model | PASS |
| 99 | Not Attempted formatting | Profile App Data Not Attempted planned=2 warnings=0 preserves exact punctuation and plurality | Deterministic model | PASS |
| 100 | Not Attempted formatting | Profile App Data Not Attempted planned=2 warnings=1 preserves exact punctuation and plurality | Deterministic model | PASS |
| 101 | Not Attempted formatting | Profile App Data Not Attempted planned=2 warnings=2 preserves exact punctuation and plurality | Deterministic model | PASS |
| 102 | Not Attempted formatting | Profile App Data Not Attempted planned=2 warnings=4096 preserves exact punctuation and plurality | Deterministic model | PASS |
| 103 | Not Attempted formatting | Profile App Data Not Attempted planned=4096 warnings=0 preserves exact punctuation and plurality | Deterministic model | PASS |
| 104 | Not Attempted formatting | Profile App Data Not Attempted planned=4096 warnings=1 preserves exact punctuation and plurality | Deterministic model | PASS |
| 105 | Not Attempted formatting | Profile App Data Not Attempted planned=4096 warnings=2 preserves exact punctuation and plurality | Deterministic model | PASS |
| 106 | Not Attempted formatting | Profile App Data Not Attempted planned=4096 warnings=4096 preserves exact punctuation and plurality | Deterministic model | PASS |
| 107 | Not Attempted formatting | Global Safari Not Attempted planned=1 warnings=0 preserves exact punctuation and plurality | Deterministic model | PASS |
| 108 | Not Attempted formatting | Global Safari Not Attempted planned=1 warnings=1 preserves exact punctuation and plurality | Deterministic model | PASS |
| 109 | Not Attempted formatting | Global Safari Not Attempted planned=1 warnings=2 preserves exact punctuation and plurality | Deterministic model | PASS |
| 110 | Not Attempted formatting | Global Safari Not Attempted planned=1 warnings=4096 preserves exact punctuation and plurality | Deterministic model | PASS |
| 111 | Not Attempted formatting | Global Safari Not Attempted planned=2 warnings=0 preserves exact punctuation and plurality | Deterministic model | PASS |
| 112 | Not Attempted formatting | Global Safari Not Attempted planned=2 warnings=1 preserves exact punctuation and plurality | Deterministic model | PASS |
| 113 | Not Attempted formatting | Global Safari Not Attempted planned=2 warnings=2 preserves exact punctuation and plurality | Deterministic model | PASS |
| 114 | Not Attempted formatting | Global Safari Not Attempted planned=2 warnings=4096 preserves exact punctuation and plurality | Deterministic model | PASS |
| 115 | Not Attempted formatting | Global Safari Not Attempted planned=4096 warnings=0 preserves exact punctuation and plurality | Deterministic model | PASS |
| 116 | Not Attempted formatting | Global Safari Not Attempted planned=4096 warnings=1 preserves exact punctuation and plurality | Deterministic model | PASS |
| 117 | Not Attempted formatting | Global Safari Not Attempted planned=4096 warnings=2 preserves exact punctuation and plurality | Deterministic model | PASS |
| 118 | Not Attempted formatting | Global Safari Not Attempted planned=4096 warnings=4096 preserves exact punctuation and plurality | Deterministic model | PASS |
| 119 | Not Attempted formatting | App Groups Not Attempted planned=1 warnings=0 preserves exact punctuation and plurality | Deterministic model | PASS |
| 120 | Not Attempted formatting | App Groups Not Attempted planned=1 warnings=1 preserves exact punctuation and plurality | Deterministic model | PASS |
| 121 | Not Attempted formatting | App Groups Not Attempted planned=1 warnings=2 preserves exact punctuation and plurality | Deterministic model | PASS |
| 122 | Not Attempted formatting | App Groups Not Attempted planned=1 warnings=4096 preserves exact punctuation and plurality | Deterministic model | PASS |
| 123 | Not Attempted formatting | App Groups Not Attempted planned=2 warnings=0 preserves exact punctuation and plurality | Deterministic model | PASS |
| 124 | Not Attempted formatting | App Groups Not Attempted planned=2 warnings=1 preserves exact punctuation and plurality | Deterministic model | PASS |
| 125 | Not Attempted formatting | App Groups Not Attempted planned=2 warnings=2 preserves exact punctuation and plurality | Deterministic model | PASS |
| 126 | Not Attempted formatting | App Groups Not Attempted planned=2 warnings=4096 preserves exact punctuation and plurality | Deterministic model | PASS |
| 127 | Not Attempted formatting | App Groups Not Attempted planned=4096 warnings=0 preserves exact punctuation and plurality | Deterministic model | PASS |
| 128 | Not Attempted formatting | App Groups Not Attempted planned=4096 warnings=1 preserves exact punctuation and plurality | Deterministic model | PASS |
| 129 | Not Attempted formatting | App Groups Not Attempted planned=4096 warnings=2 preserves exact punctuation and plurality | Deterministic model | PASS |
| 130 | Not Attempted formatting | App Groups Not Attempted planned=4096 warnings=4096 preserves exact punctuation and plurality | Deterministic model | PASS |
| 131 | Not Attempted formatting | System Global Not Attempted planned=1 warnings=0 preserves exact punctuation and plurality | Deterministic model | PASS |
| 132 | Not Attempted formatting | System Global Not Attempted planned=1 warnings=1 preserves exact punctuation and plurality | Deterministic model | PASS |
| 133 | Not Attempted formatting | System Global Not Attempted planned=1 warnings=2 preserves exact punctuation and plurality | Deterministic model | PASS |
| 134 | Not Attempted formatting | System Global Not Attempted planned=1 warnings=4096 preserves exact punctuation and plurality | Deterministic model | PASS |
| 135 | Not Attempted formatting | System Global Not Attempted planned=2 warnings=0 preserves exact punctuation and plurality | Deterministic model | PASS |
| 136 | Not Attempted formatting | System Global Not Attempted planned=2 warnings=1 preserves exact punctuation and plurality | Deterministic model | PASS |
| 137 | Not Attempted formatting | System Global Not Attempted planned=2 warnings=2 preserves exact punctuation and plurality | Deterministic model | PASS |
| 138 | Not Attempted formatting | System Global Not Attempted planned=2 warnings=4096 preserves exact punctuation and plurality | Deterministic model | PASS |
| 139 | Not Attempted formatting | System Global Not Attempted planned=4096 warnings=0 preserves exact punctuation and plurality | Deterministic model | PASS |
| 140 | Not Attempted formatting | System Global Not Attempted planned=4096 warnings=1 preserves exact punctuation and plurality | Deterministic model | PASS |
| 141 | Not Attempted formatting | System Global Not Attempted planned=4096 warnings=2 preserves exact punctuation and plurality | Deterministic model | PASS |
| 142 | Not Attempted formatting | System Global Not Attempted planned=4096 warnings=4096 preserves exact punctuation and plurality | Deterministic model | PASS |
| 143 | Not Attempted formatting | Shared System Databases Not Attempted planned=1 warnings=0 preserves exact punctuation and plurality | Deterministic model | PASS |
| 144 | Not Attempted formatting | Shared System Databases Not Attempted planned=1 warnings=1 preserves exact punctuation and plurality | Deterministic model | PASS |
| 145 | Not Attempted formatting | Shared System Databases Not Attempted planned=1 warnings=2 preserves exact punctuation and plurality | Deterministic model | PASS |
| 146 | Not Attempted formatting | Shared System Databases Not Attempted planned=1 warnings=4096 preserves exact punctuation and plurality | Deterministic model | PASS |
| 147 | Not Attempted formatting | Shared System Databases Not Attempted planned=2 warnings=0 preserves exact punctuation and plurality | Deterministic model | PASS |
| 148 | Not Attempted formatting | Shared System Databases Not Attempted planned=2 warnings=1 preserves exact punctuation and plurality | Deterministic model | PASS |
| 149 | Not Attempted formatting | Shared System Databases Not Attempted planned=2 warnings=2 preserves exact punctuation and plurality | Deterministic model | PASS |
| 150 | Not Attempted formatting | Shared System Databases Not Attempted planned=2 warnings=4096 preserves exact punctuation and plurality | Deterministic model | PASS |
| 151 | Not Attempted formatting | Shared System Databases Not Attempted planned=4096 warnings=0 preserves exact punctuation and plurality | Deterministic model | PASS |
| 152 | Not Attempted formatting | Shared System Databases Not Attempted planned=4096 warnings=1 preserves exact punctuation and plurality | Deterministic model | PASS |
| 153 | Not Attempted formatting | Shared System Databases Not Attempted planned=4096 warnings=2 preserves exact punctuation and plurality | Deterministic model | PASS |
| 154 | Not Attempted formatting | Shared System Databases Not Attempted planned=4096 warnings=4096 preserves exact punctuation and plurality | Deterministic model | PASS |
| 155 | Not Attempted formatting | Preferences Not Attempted planned=1 warnings=0 preserves exact punctuation and plurality | Deterministic model | PASS |
| 156 | Not Attempted formatting | Preferences Not Attempted planned=1 warnings=1 preserves exact punctuation and plurality | Deterministic model | PASS |
| 157 | Not Attempted formatting | Preferences Not Attempted planned=1 warnings=2 preserves exact punctuation and plurality | Deterministic model | PASS |
| 158 | Not Attempted formatting | Preferences Not Attempted planned=1 warnings=4096 preserves exact punctuation and plurality | Deterministic model | PASS |
| 159 | Not Attempted formatting | Preferences Not Attempted planned=2 warnings=0 preserves exact punctuation and plurality | Deterministic model | PASS |
| 160 | Not Attempted formatting | Preferences Not Attempted planned=2 warnings=1 preserves exact punctuation and plurality | Deterministic model | PASS |
| 161 | Not Attempted formatting | Preferences Not Attempted planned=2 warnings=2 preserves exact punctuation and plurality | Deterministic model | PASS |
| 162 | Not Attempted formatting | Preferences Not Attempted planned=2 warnings=4096 preserves exact punctuation and plurality | Deterministic model | PASS |
| 163 | Not Attempted formatting | Preferences Not Attempted planned=4096 warnings=0 preserves exact punctuation and plurality | Deterministic model | PASS |
| 164 | Not Attempted formatting | Preferences Not Attempted planned=4096 warnings=1 preserves exact punctuation and plurality | Deterministic model | PASS |
| 165 | Not Attempted formatting | Preferences Not Attempted planned=4096 warnings=2 preserves exact punctuation and plurality | Deterministic model | PASS |
| 166 | Not Attempted formatting | Preferences Not Attempted planned=4096 warnings=4096 preserves exact punctuation and plurality | Deterministic model | PASS |
| 167 | Not Attempted formatting | Keychain Not Attempted planned=1 warnings=0 preserves exact punctuation and plurality | Deterministic model | PASS |
| 168 | Not Attempted formatting | Keychain Not Attempted planned=1 warnings=1 preserves exact punctuation and plurality | Deterministic model | PASS |
| 169 | Not Attempted formatting | Keychain Not Attempted planned=1 warnings=2 preserves exact punctuation and plurality | Deterministic model | PASS |
| 170 | Not Attempted formatting | Keychain Not Attempted planned=1 warnings=4096 preserves exact punctuation and plurality | Deterministic model | PASS |
| 171 | Not Attempted formatting | Keychain Not Attempted planned=2 warnings=0 preserves exact punctuation and plurality | Deterministic model | PASS |
| 172 | Not Attempted formatting | Keychain Not Attempted planned=2 warnings=1 preserves exact punctuation and plurality | Deterministic model | PASS |
| 173 | Not Attempted formatting | Keychain Not Attempted planned=2 warnings=2 preserves exact punctuation and plurality | Deterministic model | PASS |
| 174 | Not Attempted formatting | Keychain Not Attempted planned=2 warnings=4096 preserves exact punctuation and plurality | Deterministic model | PASS |
| 175 | Not Attempted formatting | Keychain Not Attempted planned=4096 warnings=0 preserves exact punctuation and plurality | Deterministic model | PASS |
| 176 | Not Attempted formatting | Keychain Not Attempted planned=4096 warnings=1 preserves exact punctuation and plurality | Deterministic model | PASS |
| 177 | Not Attempted formatting | Keychain Not Attempted planned=4096 warnings=2 preserves exact punctuation and plurality | Deterministic model | PASS |
| 178 | Not Attempted formatting | Keychain Not Attempted planned=4096 warnings=4096 preserves exact punctuation and plurality | Deterministic model | PASS |
| 179 | Succeeded formatting | Application Data Succeeded planned=1 warnings=0 preserves exact punctuation and plurality | Deterministic model | PASS |
| 180 | Succeeded formatting | Application Data Succeeded planned=1 warnings=1 preserves exact punctuation and plurality | Deterministic model | PASS |
| 181 | Succeeded formatting | Application Data Succeeded planned=1 warnings=2 preserves exact punctuation and plurality | Deterministic model | PASS |
| 182 | Succeeded formatting | Application Data Succeeded planned=1 warnings=4096 preserves exact punctuation and plurality | Deterministic model | PASS |
| 183 | Succeeded formatting | Application Data Succeeded planned=2 warnings=0 preserves exact punctuation and plurality | Deterministic model | PASS |
| 184 | Succeeded formatting | Application Data Succeeded planned=2 warnings=1 preserves exact punctuation and plurality | Deterministic model | PASS |
| 185 | Succeeded formatting | Application Data Succeeded planned=2 warnings=2 preserves exact punctuation and plurality | Deterministic model | PASS |
| 186 | Succeeded formatting | Application Data Succeeded planned=2 warnings=4096 preserves exact punctuation and plurality | Deterministic model | PASS |
| 187 | Succeeded formatting | Application Data Succeeded planned=4096 warnings=0 preserves exact punctuation and plurality | Deterministic model | PASS |
| 188 | Succeeded formatting | Application Data Succeeded planned=4096 warnings=1 preserves exact punctuation and plurality | Deterministic model | PASS |
| 189 | Succeeded formatting | Application Data Succeeded planned=4096 warnings=2 preserves exact punctuation and plurality | Deterministic model | PASS |
| 190 | Succeeded formatting | Application Data Succeeded planned=4096 warnings=4096 preserves exact punctuation and plurality | Deterministic model | PASS |
| 191 | Succeeded formatting | Profile App Data Succeeded planned=1 warnings=0 preserves exact punctuation and plurality | Deterministic model | PASS |
| 192 | Succeeded formatting | Profile App Data Succeeded planned=1 warnings=1 preserves exact punctuation and plurality | Deterministic model | PASS |
| 193 | Succeeded formatting | Profile App Data Succeeded planned=1 warnings=2 preserves exact punctuation and plurality | Deterministic model | PASS |
| 194 | Succeeded formatting | Profile App Data Succeeded planned=1 warnings=4096 preserves exact punctuation and plurality | Deterministic model | PASS |
| 195 | Succeeded formatting | Profile App Data Succeeded planned=2 warnings=0 preserves exact punctuation and plurality | Deterministic model | PASS |
| 196 | Succeeded formatting | Profile App Data Succeeded planned=2 warnings=1 preserves exact punctuation and plurality | Deterministic model | PASS |
| 197 | Succeeded formatting | Profile App Data Succeeded planned=2 warnings=2 preserves exact punctuation and plurality | Deterministic model | PASS |
| 198 | Succeeded formatting | Profile App Data Succeeded planned=2 warnings=4096 preserves exact punctuation and plurality | Deterministic model | PASS |
| 199 | Succeeded formatting | Profile App Data Succeeded planned=4096 warnings=0 preserves exact punctuation and plurality | Deterministic model | PASS |
| 200 | Succeeded formatting | Profile App Data Succeeded planned=4096 warnings=1 preserves exact punctuation and plurality | Deterministic model | PASS |
| 201 | Succeeded formatting | Profile App Data Succeeded planned=4096 warnings=2 preserves exact punctuation and plurality | Deterministic model | PASS |
| 202 | Succeeded formatting | Profile App Data Succeeded planned=4096 warnings=4096 preserves exact punctuation and plurality | Deterministic model | PASS |
| 203 | Succeeded formatting | Global Safari Succeeded planned=1 warnings=0 preserves exact punctuation and plurality | Deterministic model | PASS |
| 204 | Succeeded formatting | Global Safari Succeeded planned=1 warnings=1 preserves exact punctuation and plurality | Deterministic model | PASS |
| 205 | Succeeded formatting | Global Safari Succeeded planned=1 warnings=2 preserves exact punctuation and plurality | Deterministic model | PASS |
| 206 | Succeeded formatting | Global Safari Succeeded planned=1 warnings=4096 preserves exact punctuation and plurality | Deterministic model | PASS |
| 207 | Succeeded formatting | Global Safari Succeeded planned=2 warnings=0 preserves exact punctuation and plurality | Deterministic model | PASS |
| 208 | Succeeded formatting | Global Safari Succeeded planned=2 warnings=1 preserves exact punctuation and plurality | Deterministic model | PASS |
| 209 | Succeeded formatting | Global Safari Succeeded planned=2 warnings=2 preserves exact punctuation and plurality | Deterministic model | PASS |
| 210 | Succeeded formatting | Global Safari Succeeded planned=2 warnings=4096 preserves exact punctuation and plurality | Deterministic model | PASS |
| 211 | Succeeded formatting | Global Safari Succeeded planned=4096 warnings=0 preserves exact punctuation and plurality | Deterministic model | PASS |
| 212 | Succeeded formatting | Global Safari Succeeded planned=4096 warnings=1 preserves exact punctuation and plurality | Deterministic model | PASS |
| 213 | Succeeded formatting | Global Safari Succeeded planned=4096 warnings=2 preserves exact punctuation and plurality | Deterministic model | PASS |
| 214 | Succeeded formatting | Global Safari Succeeded planned=4096 warnings=4096 preserves exact punctuation and plurality | Deterministic model | PASS |
| 215 | Succeeded formatting | App Groups Succeeded planned=1 warnings=0 preserves exact punctuation and plurality | Deterministic model | PASS |
| 216 | Succeeded formatting | App Groups Succeeded planned=1 warnings=1 preserves exact punctuation and plurality | Deterministic model | PASS |
| 217 | Succeeded formatting | App Groups Succeeded planned=1 warnings=2 preserves exact punctuation and plurality | Deterministic model | PASS |
| 218 | Succeeded formatting | App Groups Succeeded planned=1 warnings=4096 preserves exact punctuation and plurality | Deterministic model | PASS |
| 219 | Succeeded formatting | App Groups Succeeded planned=2 warnings=0 preserves exact punctuation and plurality | Deterministic model | PASS |
| 220 | Succeeded formatting | App Groups Succeeded planned=2 warnings=1 preserves exact punctuation and plurality | Deterministic model | PASS |
| 221 | Succeeded formatting | App Groups Succeeded planned=2 warnings=2 preserves exact punctuation and plurality | Deterministic model | PASS |
| 222 | Succeeded formatting | App Groups Succeeded planned=2 warnings=4096 preserves exact punctuation and plurality | Deterministic model | PASS |
| 223 | Succeeded formatting | App Groups Succeeded planned=4096 warnings=0 preserves exact punctuation and plurality | Deterministic model | PASS |
| 224 | Succeeded formatting | App Groups Succeeded planned=4096 warnings=1 preserves exact punctuation and plurality | Deterministic model | PASS |
| 225 | Succeeded formatting | App Groups Succeeded planned=4096 warnings=2 preserves exact punctuation and plurality | Deterministic model | PASS |
| 226 | Succeeded formatting | App Groups Succeeded planned=4096 warnings=4096 preserves exact punctuation and plurality | Deterministic model | PASS |
| 227 | Succeeded formatting | System Global Succeeded planned=1 warnings=0 preserves exact punctuation and plurality | Deterministic model | PASS |
| 228 | Succeeded formatting | System Global Succeeded planned=1 warnings=1 preserves exact punctuation and plurality | Deterministic model | PASS |
| 229 | Succeeded formatting | System Global Succeeded planned=1 warnings=2 preserves exact punctuation and plurality | Deterministic model | PASS |
| 230 | Succeeded formatting | System Global Succeeded planned=1 warnings=4096 preserves exact punctuation and plurality | Deterministic model | PASS |
| 231 | Succeeded formatting | System Global Succeeded planned=2 warnings=0 preserves exact punctuation and plurality | Deterministic model | PASS |
| 232 | Succeeded formatting | System Global Succeeded planned=2 warnings=1 preserves exact punctuation and plurality | Deterministic model | PASS |
| 233 | Succeeded formatting | System Global Succeeded planned=2 warnings=2 preserves exact punctuation and plurality | Deterministic model | PASS |
| 234 | Succeeded formatting | System Global Succeeded planned=2 warnings=4096 preserves exact punctuation and plurality | Deterministic model | PASS |
| 235 | Succeeded formatting | System Global Succeeded planned=4096 warnings=0 preserves exact punctuation and plurality | Deterministic model | PASS |
| 236 | Succeeded formatting | System Global Succeeded planned=4096 warnings=1 preserves exact punctuation and plurality | Deterministic model | PASS |
| 237 | Succeeded formatting | System Global Succeeded planned=4096 warnings=2 preserves exact punctuation and plurality | Deterministic model | PASS |
| 238 | Succeeded formatting | System Global Succeeded planned=4096 warnings=4096 preserves exact punctuation and plurality | Deterministic model | PASS |
| 239 | Succeeded formatting | Shared System Databases Succeeded planned=1 warnings=0 preserves exact punctuation and plurality | Deterministic model | PASS |
| 240 | Succeeded formatting | Shared System Databases Succeeded planned=1 warnings=1 preserves exact punctuation and plurality | Deterministic model | PASS |
| 241 | Succeeded formatting | Shared System Databases Succeeded planned=1 warnings=2 preserves exact punctuation and plurality | Deterministic model | PASS |
| 242 | Succeeded formatting | Shared System Databases Succeeded planned=1 warnings=4096 preserves exact punctuation and plurality | Deterministic model | PASS |
| 243 | Succeeded formatting | Shared System Databases Succeeded planned=2 warnings=0 preserves exact punctuation and plurality | Deterministic model | PASS |
| 244 | Succeeded formatting | Shared System Databases Succeeded planned=2 warnings=1 preserves exact punctuation and plurality | Deterministic model | PASS |
| 245 | Succeeded formatting | Shared System Databases Succeeded planned=2 warnings=2 preserves exact punctuation and plurality | Deterministic model | PASS |
| 246 | Succeeded formatting | Shared System Databases Succeeded planned=2 warnings=4096 preserves exact punctuation and plurality | Deterministic model | PASS |
| 247 | Succeeded formatting | Shared System Databases Succeeded planned=4096 warnings=0 preserves exact punctuation and plurality | Deterministic model | PASS |
| 248 | Succeeded formatting | Shared System Databases Succeeded planned=4096 warnings=1 preserves exact punctuation and plurality | Deterministic model | PASS |
| 249 | Succeeded formatting | Shared System Databases Succeeded planned=4096 warnings=2 preserves exact punctuation and plurality | Deterministic model | PASS |
| 250 | Succeeded formatting | Shared System Databases Succeeded planned=4096 warnings=4096 preserves exact punctuation and plurality | Deterministic model | PASS |
| 251 | Succeeded formatting | Preferences Succeeded planned=1 warnings=0 preserves exact punctuation and plurality | Deterministic model | PASS |
| 252 | Succeeded formatting | Preferences Succeeded planned=1 warnings=1 preserves exact punctuation and plurality | Deterministic model | PASS |
| 253 | Succeeded formatting | Preferences Succeeded planned=1 warnings=2 preserves exact punctuation and plurality | Deterministic model | PASS |
| 254 | Succeeded formatting | Preferences Succeeded planned=1 warnings=4096 preserves exact punctuation and plurality | Deterministic model | PASS |
| 255 | Succeeded formatting | Preferences Succeeded planned=2 warnings=0 preserves exact punctuation and plurality | Deterministic model | PASS |
| 256 | Succeeded formatting | Preferences Succeeded planned=2 warnings=1 preserves exact punctuation and plurality | Deterministic model | PASS |
| 257 | Succeeded formatting | Preferences Succeeded planned=2 warnings=2 preserves exact punctuation and plurality | Deterministic model | PASS |
| 258 | Succeeded formatting | Preferences Succeeded planned=2 warnings=4096 preserves exact punctuation and plurality | Deterministic model | PASS |
| 259 | Succeeded formatting | Preferences Succeeded planned=4096 warnings=0 preserves exact punctuation and plurality | Deterministic model | PASS |
| 260 | Succeeded formatting | Preferences Succeeded planned=4096 warnings=1 preserves exact punctuation and plurality | Deterministic model | PASS |
| 261 | Succeeded formatting | Preferences Succeeded planned=4096 warnings=2 preserves exact punctuation and plurality | Deterministic model | PASS |
| 262 | Succeeded formatting | Preferences Succeeded planned=4096 warnings=4096 preserves exact punctuation and plurality | Deterministic model | PASS |
| 263 | Succeeded formatting | Keychain Succeeded planned=1 warnings=0 preserves exact punctuation and plurality | Deterministic model | PASS |
| 264 | Succeeded formatting | Keychain Succeeded planned=1 warnings=1 preserves exact punctuation and plurality | Deterministic model | PASS |
| 265 | Succeeded formatting | Keychain Succeeded planned=1 warnings=2 preserves exact punctuation and plurality | Deterministic model | PASS |
| 266 | Succeeded formatting | Keychain Succeeded planned=1 warnings=4096 preserves exact punctuation and plurality | Deterministic model | PASS |
| 267 | Succeeded formatting | Keychain Succeeded planned=2 warnings=0 preserves exact punctuation and plurality | Deterministic model | PASS |
| 268 | Succeeded formatting | Keychain Succeeded planned=2 warnings=1 preserves exact punctuation and plurality | Deterministic model | PASS |
| 269 | Succeeded formatting | Keychain Succeeded planned=2 warnings=2 preserves exact punctuation and plurality | Deterministic model | PASS |
| 270 | Succeeded formatting | Keychain Succeeded planned=2 warnings=4096 preserves exact punctuation and plurality | Deterministic model | PASS |
| 271 | Succeeded formatting | Keychain Succeeded planned=4096 warnings=0 preserves exact punctuation and plurality | Deterministic model | PASS |
| 272 | Succeeded formatting | Keychain Succeeded planned=4096 warnings=1 preserves exact punctuation and plurality | Deterministic model | PASS |
| 273 | Succeeded formatting | Keychain Succeeded planned=4096 warnings=2 preserves exact punctuation and plurality | Deterministic model | PASS |
| 274 | Succeeded formatting | Keychain Succeeded planned=4096 warnings=4096 preserves exact punctuation and plurality | Deterministic model | PASS |
| 275 | Failed formatting | Application Data Failed rollback=Rollback Not Performed warnings=0 failure-message=plain | Deterministic model | PASS |
| 276 | Failed formatting | Application Data Failed rollback=Rollback Not Performed warnings=0 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 277 | Failed formatting | Application Data Failed rollback=Rollback Not Performed warnings=1 failure-message=plain | Deterministic model | PASS |
| 278 | Failed formatting | Application Data Failed rollback=Rollback Not Performed warnings=1 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 279 | Failed formatting | Application Data Failed rollback=Rollback Not Performed warnings=2 failure-message=plain | Deterministic model | PASS |
| 280 | Failed formatting | Application Data Failed rollback=Rollback Not Performed warnings=2 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 281 | Failed formatting | Application Data Failed rollback=Rollback Not Performed warnings=4096 failure-message=plain | Deterministic model | PASS |
| 282 | Failed formatting | Application Data Failed rollback=Rollback Not Performed warnings=4096 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 283 | Failed formatting | Application Data Failed rollback=Rollback Completed warnings=0 failure-message=plain | Deterministic model | PASS |
| 284 | Failed formatting | Application Data Failed rollback=Rollback Completed warnings=0 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 285 | Failed formatting | Application Data Failed rollback=Rollback Completed warnings=1 failure-message=plain | Deterministic model | PASS |
| 286 | Failed formatting | Application Data Failed rollback=Rollback Completed warnings=1 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 287 | Failed formatting | Application Data Failed rollback=Rollback Completed warnings=2 failure-message=plain | Deterministic model | PASS |
| 288 | Failed formatting | Application Data Failed rollback=Rollback Completed warnings=2 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 289 | Failed formatting | Application Data Failed rollback=Rollback Completed warnings=4096 failure-message=plain | Deterministic model | PASS |
| 290 | Failed formatting | Application Data Failed rollback=Rollback Completed warnings=4096 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 291 | Failed formatting | Application Data Failed rollback=Rollback Incomplete warnings=0 failure-message=plain | Deterministic model | PASS |
| 292 | Failed formatting | Application Data Failed rollback=Rollback Incomplete warnings=0 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 293 | Failed formatting | Application Data Failed rollback=Rollback Incomplete warnings=1 failure-message=plain | Deterministic model | PASS |
| 294 | Failed formatting | Application Data Failed rollback=Rollback Incomplete warnings=1 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 295 | Failed formatting | Application Data Failed rollback=Rollback Incomplete warnings=2 failure-message=plain | Deterministic model | PASS |
| 296 | Failed formatting | Application Data Failed rollback=Rollback Incomplete warnings=2 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 297 | Failed formatting | Application Data Failed rollback=Rollback Incomplete warnings=4096 failure-message=plain | Deterministic model | PASS |
| 298 | Failed formatting | Application Data Failed rollback=Rollback Incomplete warnings=4096 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 299 | Failed formatting | Profile App Data Failed rollback=Rollback Not Performed warnings=0 failure-message=plain | Deterministic model | PASS |
| 300 | Failed formatting | Profile App Data Failed rollback=Rollback Not Performed warnings=0 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 301 | Failed formatting | Profile App Data Failed rollback=Rollback Not Performed warnings=1 failure-message=plain | Deterministic model | PASS |
| 302 | Failed formatting | Profile App Data Failed rollback=Rollback Not Performed warnings=1 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 303 | Failed formatting | Profile App Data Failed rollback=Rollback Not Performed warnings=2 failure-message=plain | Deterministic model | PASS |
| 304 | Failed formatting | Profile App Data Failed rollback=Rollback Not Performed warnings=2 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 305 | Failed formatting | Profile App Data Failed rollback=Rollback Not Performed warnings=4096 failure-message=plain | Deterministic model | PASS |
| 306 | Failed formatting | Profile App Data Failed rollback=Rollback Not Performed warnings=4096 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 307 | Failed formatting | Profile App Data Failed rollback=Rollback Completed warnings=0 failure-message=plain | Deterministic model | PASS |
| 308 | Failed formatting | Profile App Data Failed rollback=Rollback Completed warnings=0 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 309 | Failed formatting | Profile App Data Failed rollback=Rollback Completed warnings=1 failure-message=plain | Deterministic model | PASS |
| 310 | Failed formatting | Profile App Data Failed rollback=Rollback Completed warnings=1 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 311 | Failed formatting | Profile App Data Failed rollback=Rollback Completed warnings=2 failure-message=plain | Deterministic model | PASS |
| 312 | Failed formatting | Profile App Data Failed rollback=Rollback Completed warnings=2 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 313 | Failed formatting | Profile App Data Failed rollback=Rollback Completed warnings=4096 failure-message=plain | Deterministic model | PASS |
| 314 | Failed formatting | Profile App Data Failed rollback=Rollback Completed warnings=4096 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 315 | Failed formatting | Profile App Data Failed rollback=Rollback Incomplete warnings=0 failure-message=plain | Deterministic model | PASS |
| 316 | Failed formatting | Profile App Data Failed rollback=Rollback Incomplete warnings=0 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 317 | Failed formatting | Profile App Data Failed rollback=Rollback Incomplete warnings=1 failure-message=plain | Deterministic model | PASS |
| 318 | Failed formatting | Profile App Data Failed rollback=Rollback Incomplete warnings=1 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 319 | Failed formatting | Profile App Data Failed rollback=Rollback Incomplete warnings=2 failure-message=plain | Deterministic model | PASS |
| 320 | Failed formatting | Profile App Data Failed rollback=Rollback Incomplete warnings=2 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 321 | Failed formatting | Profile App Data Failed rollback=Rollback Incomplete warnings=4096 failure-message=plain | Deterministic model | PASS |
| 322 | Failed formatting | Profile App Data Failed rollback=Rollback Incomplete warnings=4096 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 323 | Failed formatting | Global Safari Failed rollback=Rollback Not Performed warnings=0 failure-message=plain | Deterministic model | PASS |
| 324 | Failed formatting | Global Safari Failed rollback=Rollback Not Performed warnings=0 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 325 | Failed formatting | Global Safari Failed rollback=Rollback Not Performed warnings=1 failure-message=plain | Deterministic model | PASS |
| 326 | Failed formatting | Global Safari Failed rollback=Rollback Not Performed warnings=1 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 327 | Failed formatting | Global Safari Failed rollback=Rollback Not Performed warnings=2 failure-message=plain | Deterministic model | PASS |
| 328 | Failed formatting | Global Safari Failed rollback=Rollback Not Performed warnings=2 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 329 | Failed formatting | Global Safari Failed rollback=Rollback Not Performed warnings=4096 failure-message=plain | Deterministic model | PASS |
| 330 | Failed formatting | Global Safari Failed rollback=Rollback Not Performed warnings=4096 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 331 | Failed formatting | Global Safari Failed rollback=Rollback Completed warnings=0 failure-message=plain | Deterministic model | PASS |
| 332 | Failed formatting | Global Safari Failed rollback=Rollback Completed warnings=0 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 333 | Failed formatting | Global Safari Failed rollback=Rollback Completed warnings=1 failure-message=plain | Deterministic model | PASS |
| 334 | Failed formatting | Global Safari Failed rollback=Rollback Completed warnings=1 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 335 | Failed formatting | Global Safari Failed rollback=Rollback Completed warnings=2 failure-message=plain | Deterministic model | PASS |
| 336 | Failed formatting | Global Safari Failed rollback=Rollback Completed warnings=2 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 337 | Failed formatting | Global Safari Failed rollback=Rollback Completed warnings=4096 failure-message=plain | Deterministic model | PASS |
| 338 | Failed formatting | Global Safari Failed rollback=Rollback Completed warnings=4096 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 339 | Failed formatting | Global Safari Failed rollback=Rollback Incomplete warnings=0 failure-message=plain | Deterministic model | PASS |
| 340 | Failed formatting | Global Safari Failed rollback=Rollback Incomplete warnings=0 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 341 | Failed formatting | Global Safari Failed rollback=Rollback Incomplete warnings=1 failure-message=plain | Deterministic model | PASS |
| 342 | Failed formatting | Global Safari Failed rollback=Rollback Incomplete warnings=1 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 343 | Failed formatting | Global Safari Failed rollback=Rollback Incomplete warnings=2 failure-message=plain | Deterministic model | PASS |
| 344 | Failed formatting | Global Safari Failed rollback=Rollback Incomplete warnings=2 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 345 | Failed formatting | Global Safari Failed rollback=Rollback Incomplete warnings=4096 failure-message=plain | Deterministic model | PASS |
| 346 | Failed formatting | Global Safari Failed rollback=Rollback Incomplete warnings=4096 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 347 | Failed formatting | App Groups Failed rollback=Rollback Not Performed warnings=0 failure-message=plain | Deterministic model | PASS |
| 348 | Failed formatting | App Groups Failed rollback=Rollback Not Performed warnings=0 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 349 | Failed formatting | App Groups Failed rollback=Rollback Not Performed warnings=1 failure-message=plain | Deterministic model | PASS |
| 350 | Failed formatting | App Groups Failed rollback=Rollback Not Performed warnings=1 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 351 | Failed formatting | App Groups Failed rollback=Rollback Not Performed warnings=2 failure-message=plain | Deterministic model | PASS |
| 352 | Failed formatting | App Groups Failed rollback=Rollback Not Performed warnings=2 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 353 | Failed formatting | App Groups Failed rollback=Rollback Not Performed warnings=4096 failure-message=plain | Deterministic model | PASS |
| 354 | Failed formatting | App Groups Failed rollback=Rollback Not Performed warnings=4096 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 355 | Failed formatting | App Groups Failed rollback=Rollback Completed warnings=0 failure-message=plain | Deterministic model | PASS |
| 356 | Failed formatting | App Groups Failed rollback=Rollback Completed warnings=0 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 357 | Failed formatting | App Groups Failed rollback=Rollback Completed warnings=1 failure-message=plain | Deterministic model | PASS |
| 358 | Failed formatting | App Groups Failed rollback=Rollback Completed warnings=1 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 359 | Failed formatting | App Groups Failed rollback=Rollback Completed warnings=2 failure-message=plain | Deterministic model | PASS |
| 360 | Failed formatting | App Groups Failed rollback=Rollback Completed warnings=2 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 361 | Failed formatting | App Groups Failed rollback=Rollback Completed warnings=4096 failure-message=plain | Deterministic model | PASS |
| 362 | Failed formatting | App Groups Failed rollback=Rollback Completed warnings=4096 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 363 | Failed formatting | App Groups Failed rollback=Rollback Incomplete warnings=0 failure-message=plain | Deterministic model | PASS |
| 364 | Failed formatting | App Groups Failed rollback=Rollback Incomplete warnings=0 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 365 | Failed formatting | App Groups Failed rollback=Rollback Incomplete warnings=1 failure-message=plain | Deterministic model | PASS |
| 366 | Failed formatting | App Groups Failed rollback=Rollback Incomplete warnings=1 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 367 | Failed formatting | App Groups Failed rollback=Rollback Incomplete warnings=2 failure-message=plain | Deterministic model | PASS |
| 368 | Failed formatting | App Groups Failed rollback=Rollback Incomplete warnings=2 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 369 | Failed formatting | App Groups Failed rollback=Rollback Incomplete warnings=4096 failure-message=plain | Deterministic model | PASS |
| 370 | Failed formatting | App Groups Failed rollback=Rollback Incomplete warnings=4096 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 371 | Failed formatting | System Global Failed rollback=Rollback Not Performed warnings=0 failure-message=plain | Deterministic model | PASS |
| 372 | Failed formatting | System Global Failed rollback=Rollback Not Performed warnings=0 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 373 | Failed formatting | System Global Failed rollback=Rollback Not Performed warnings=1 failure-message=plain | Deterministic model | PASS |
| 374 | Failed formatting | System Global Failed rollback=Rollback Not Performed warnings=1 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 375 | Failed formatting | System Global Failed rollback=Rollback Not Performed warnings=2 failure-message=plain | Deterministic model | PASS |
| 376 | Failed formatting | System Global Failed rollback=Rollback Not Performed warnings=2 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 377 | Failed formatting | System Global Failed rollback=Rollback Not Performed warnings=4096 failure-message=plain | Deterministic model | PASS |
| 378 | Failed formatting | System Global Failed rollback=Rollback Not Performed warnings=4096 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 379 | Failed formatting | System Global Failed rollback=Rollback Completed warnings=0 failure-message=plain | Deterministic model | PASS |
| 380 | Failed formatting | System Global Failed rollback=Rollback Completed warnings=0 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 381 | Failed formatting | System Global Failed rollback=Rollback Completed warnings=1 failure-message=plain | Deterministic model | PASS |
| 382 | Failed formatting | System Global Failed rollback=Rollback Completed warnings=1 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 383 | Failed formatting | System Global Failed rollback=Rollback Completed warnings=2 failure-message=plain | Deterministic model | PASS |
| 384 | Failed formatting | System Global Failed rollback=Rollback Completed warnings=2 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 385 | Failed formatting | System Global Failed rollback=Rollback Completed warnings=4096 failure-message=plain | Deterministic model | PASS |
| 386 | Failed formatting | System Global Failed rollback=Rollback Completed warnings=4096 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 387 | Failed formatting | System Global Failed rollback=Rollback Incomplete warnings=0 failure-message=plain | Deterministic model | PASS |
| 388 | Failed formatting | System Global Failed rollback=Rollback Incomplete warnings=0 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 389 | Failed formatting | System Global Failed rollback=Rollback Incomplete warnings=1 failure-message=plain | Deterministic model | PASS |
| 390 | Failed formatting | System Global Failed rollback=Rollback Incomplete warnings=1 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 391 | Failed formatting | System Global Failed rollback=Rollback Incomplete warnings=2 failure-message=plain | Deterministic model | PASS |
| 392 | Failed formatting | System Global Failed rollback=Rollback Incomplete warnings=2 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 393 | Failed formatting | System Global Failed rollback=Rollback Incomplete warnings=4096 failure-message=plain | Deterministic model | PASS |
| 394 | Failed formatting | System Global Failed rollback=Rollback Incomplete warnings=4096 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 395 | Failed formatting | Shared System Databases Failed rollback=Rollback Not Performed warnings=0 failure-message=plain | Deterministic model | PASS |
| 396 | Failed formatting | Shared System Databases Failed rollback=Rollback Not Performed warnings=0 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 397 | Failed formatting | Shared System Databases Failed rollback=Rollback Not Performed warnings=1 failure-message=plain | Deterministic model | PASS |
| 398 | Failed formatting | Shared System Databases Failed rollback=Rollback Not Performed warnings=1 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 399 | Failed formatting | Shared System Databases Failed rollback=Rollback Not Performed warnings=2 failure-message=plain | Deterministic model | PASS |
| 400 | Failed formatting | Shared System Databases Failed rollback=Rollback Not Performed warnings=2 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 401 | Failed formatting | Shared System Databases Failed rollback=Rollback Not Performed warnings=4096 failure-message=plain | Deterministic model | PASS |
| 402 | Failed formatting | Shared System Databases Failed rollback=Rollback Not Performed warnings=4096 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 403 | Failed formatting | Shared System Databases Failed rollback=Rollback Completed warnings=0 failure-message=plain | Deterministic model | PASS |
| 404 | Failed formatting | Shared System Databases Failed rollback=Rollback Completed warnings=0 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 405 | Failed formatting | Shared System Databases Failed rollback=Rollback Completed warnings=1 failure-message=plain | Deterministic model | PASS |
| 406 | Failed formatting | Shared System Databases Failed rollback=Rollback Completed warnings=1 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 407 | Failed formatting | Shared System Databases Failed rollback=Rollback Completed warnings=2 failure-message=plain | Deterministic model | PASS |
| 408 | Failed formatting | Shared System Databases Failed rollback=Rollback Completed warnings=2 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 409 | Failed formatting | Shared System Databases Failed rollback=Rollback Completed warnings=4096 failure-message=plain | Deterministic model | PASS |
| 410 | Failed formatting | Shared System Databases Failed rollback=Rollback Completed warnings=4096 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 411 | Failed formatting | Shared System Databases Failed rollback=Rollback Incomplete warnings=0 failure-message=plain | Deterministic model | PASS |
| 412 | Failed formatting | Shared System Databases Failed rollback=Rollback Incomplete warnings=0 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 413 | Failed formatting | Shared System Databases Failed rollback=Rollback Incomplete warnings=1 failure-message=plain | Deterministic model | PASS |
| 414 | Failed formatting | Shared System Databases Failed rollback=Rollback Incomplete warnings=1 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 415 | Failed formatting | Shared System Databases Failed rollback=Rollback Incomplete warnings=2 failure-message=plain | Deterministic model | PASS |
| 416 | Failed formatting | Shared System Databases Failed rollback=Rollback Incomplete warnings=2 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 417 | Failed formatting | Shared System Databases Failed rollback=Rollback Incomplete warnings=4096 failure-message=plain | Deterministic model | PASS |
| 418 | Failed formatting | Shared System Databases Failed rollback=Rollback Incomplete warnings=4096 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 419 | Failed formatting | Preferences Failed rollback=Rollback Not Performed warnings=0 failure-message=plain | Deterministic model | PASS |
| 420 | Failed formatting | Preferences Failed rollback=Rollback Not Performed warnings=0 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 421 | Failed formatting | Preferences Failed rollback=Rollback Not Performed warnings=1 failure-message=plain | Deterministic model | PASS |
| 422 | Failed formatting | Preferences Failed rollback=Rollback Not Performed warnings=1 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 423 | Failed formatting | Preferences Failed rollback=Rollback Not Performed warnings=2 failure-message=plain | Deterministic model | PASS |
| 424 | Failed formatting | Preferences Failed rollback=Rollback Not Performed warnings=2 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 425 | Failed formatting | Preferences Failed rollback=Rollback Not Performed warnings=4096 failure-message=plain | Deterministic model | PASS |
| 426 | Failed formatting | Preferences Failed rollback=Rollback Not Performed warnings=4096 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 427 | Failed formatting | Preferences Failed rollback=Rollback Completed warnings=0 failure-message=plain | Deterministic model | PASS |
| 428 | Failed formatting | Preferences Failed rollback=Rollback Completed warnings=0 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 429 | Failed formatting | Preferences Failed rollback=Rollback Completed warnings=1 failure-message=plain | Deterministic model | PASS |
| 430 | Failed formatting | Preferences Failed rollback=Rollback Completed warnings=1 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 431 | Failed formatting | Preferences Failed rollback=Rollback Completed warnings=2 failure-message=plain | Deterministic model | PASS |
| 432 | Failed formatting | Preferences Failed rollback=Rollback Completed warnings=2 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 433 | Failed formatting | Preferences Failed rollback=Rollback Completed warnings=4096 failure-message=plain | Deterministic model | PASS |
| 434 | Failed formatting | Preferences Failed rollback=Rollback Completed warnings=4096 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 435 | Failed formatting | Preferences Failed rollback=Rollback Incomplete warnings=0 failure-message=plain | Deterministic model | PASS |
| 436 | Failed formatting | Preferences Failed rollback=Rollback Incomplete warnings=0 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 437 | Failed formatting | Preferences Failed rollback=Rollback Incomplete warnings=1 failure-message=plain | Deterministic model | PASS |
| 438 | Failed formatting | Preferences Failed rollback=Rollback Incomplete warnings=1 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 439 | Failed formatting | Preferences Failed rollback=Rollback Incomplete warnings=2 failure-message=plain | Deterministic model | PASS |
| 440 | Failed formatting | Preferences Failed rollback=Rollback Incomplete warnings=2 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 441 | Failed formatting | Preferences Failed rollback=Rollback Incomplete warnings=4096 failure-message=plain | Deterministic model | PASS |
| 442 | Failed formatting | Preferences Failed rollback=Rollback Incomplete warnings=4096 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 443 | Failed formatting | Keychain Failed rollback=Rollback Not Performed warnings=0 failure-message=plain | Deterministic model | PASS |
| 444 | Failed formatting | Keychain Failed rollback=Rollback Not Performed warnings=0 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 445 | Failed formatting | Keychain Failed rollback=Rollback Not Performed warnings=1 failure-message=plain | Deterministic model | PASS |
| 446 | Failed formatting | Keychain Failed rollback=Rollback Not Performed warnings=1 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 447 | Failed formatting | Keychain Failed rollback=Rollback Not Performed warnings=2 failure-message=plain | Deterministic model | PASS |
| 448 | Failed formatting | Keychain Failed rollback=Rollback Not Performed warnings=2 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 449 | Failed formatting | Keychain Failed rollback=Rollback Not Performed warnings=4096 failure-message=plain | Deterministic model | PASS |
| 450 | Failed formatting | Keychain Failed rollback=Rollback Not Performed warnings=4096 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 451 | Failed formatting | Keychain Failed rollback=Rollback Completed warnings=0 failure-message=plain | Deterministic model | PASS |
| 452 | Failed formatting | Keychain Failed rollback=Rollback Completed warnings=0 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 453 | Failed formatting | Keychain Failed rollback=Rollback Completed warnings=1 failure-message=plain | Deterministic model | PASS |
| 454 | Failed formatting | Keychain Failed rollback=Rollback Completed warnings=1 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 455 | Failed formatting | Keychain Failed rollback=Rollback Completed warnings=2 failure-message=plain | Deterministic model | PASS |
| 456 | Failed formatting | Keychain Failed rollback=Rollback Completed warnings=2 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 457 | Failed formatting | Keychain Failed rollback=Rollback Completed warnings=4096 failure-message=plain | Deterministic model | PASS |
| 458 | Failed formatting | Keychain Failed rollback=Rollback Completed warnings=4096 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 459 | Failed formatting | Keychain Failed rollback=Rollback Incomplete warnings=0 failure-message=plain | Deterministic model | PASS |
| 460 | Failed formatting | Keychain Failed rollback=Rollback Incomplete warnings=0 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 461 | Failed formatting | Keychain Failed rollback=Rollback Incomplete warnings=1 failure-message=plain | Deterministic model | PASS |
| 462 | Failed formatting | Keychain Failed rollback=Rollback Incomplete warnings=1 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 463 | Failed formatting | Keychain Failed rollback=Rollback Incomplete warnings=2 failure-message=plain | Deterministic model | PASS |
| 464 | Failed formatting | Keychain Failed rollback=Rollback Incomplete warnings=2 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 465 | Failed formatting | Keychain Failed rollback=Rollback Incomplete warnings=4096 failure-message=plain | Deterministic model | PASS |
| 466 | Failed formatting | Keychain Failed rollback=Rollback Incomplete warnings=4096 failure-message=punctuation-newline-UTF8 | Deterministic model | PASS |
| 467 | Canonical permutations | Permutation 001 input order (1, 128, 4, 64, 16, 32, 2, 8) renders canonical eight-component order | Deterministic permutation model | PASS |
| 468 | Canonical permutations | Permutation 002 input order (1, 2, 64, 8, 32, 128, 4, 16) renders canonical eight-component order | Deterministic permutation model | PASS |
| 469 | Canonical permutations | Permutation 003 input order (2, 64, 128, 1, 8, 32, 4, 16) renders canonical eight-component order | Deterministic permutation model | PASS |
| 470 | Canonical permutations | Permutation 004 input order (128, 1, 32, 2, 8, 16, 64, 4) renders canonical eight-component order | Deterministic permutation model | PASS |
| 471 | Canonical permutations | Permutation 005 input order (2, 64, 8, 16, 1, 32, 128, 4) renders canonical eight-component order | Deterministic permutation model | PASS |
| 472 | Canonical permutations | Permutation 006 input order (128, 8, 32, 4, 1, 16, 2, 64) renders canonical eight-component order | Deterministic permutation model | PASS |
| 473 | Canonical permutations | Permutation 007 input order (64, 16, 2, 1, 128, 4, 8, 32) renders canonical eight-component order | Deterministic permutation model | PASS |
| 474 | Canonical permutations | Permutation 008 input order (64, 1, 2, 128, 4, 8, 16, 32) renders canonical eight-component order | Deterministic permutation model | PASS |
| 475 | Canonical permutations | Permutation 009 input order (16, 8, 64, 1, 2, 4, 32, 128) renders canonical eight-component order | Deterministic permutation model | PASS |
| 476 | Canonical permutations | Permutation 010 input order (2, 128, 64, 4, 32, 16, 8, 1) renders canonical eight-component order | Deterministic permutation model | PASS |
| 477 | Canonical permutations | Permutation 011 input order (2, 64, 1, 4, 32, 128, 8, 16) renders canonical eight-component order | Deterministic permutation model | PASS |
| 478 | Canonical permutations | Permutation 012 input order (4, 128, 32, 2, 8, 16, 1, 64) renders canonical eight-component order | Deterministic permutation model | PASS |
| 479 | Canonical permutations | Permutation 013 input order (8, 16, 32, 1, 64, 128, 4, 2) renders canonical eight-component order | Deterministic permutation model | PASS |
| 480 | Canonical permutations | Permutation 014 input order (32, 16, 4, 128, 1, 8, 64, 2) renders canonical eight-component order | Deterministic permutation model | PASS |
| 481 | Canonical permutations | Permutation 015 input order (8, 1, 64, 16, 2, 128, 32, 4) renders canonical eight-component order | Deterministic permutation model | PASS |
| 482 | Canonical permutations | Permutation 016 input order (2, 4, 1, 128, 8, 64, 32, 16) renders canonical eight-component order | Deterministic permutation model | PASS |
| 483 | Canonical permutations | Permutation 017 input order (128, 32, 8, 16, 64, 2, 4, 1) renders canonical eight-component order | Deterministic permutation model | PASS |
| 484 | Canonical permutations | Permutation 018 input order (1, 16, 4, 64, 2, 8, 128, 32) renders canonical eight-component order | Deterministic permutation model | PASS |
| 485 | Canonical permutations | Permutation 019 input order (8, 1, 2, 16, 4, 128, 64, 32) renders canonical eight-component order | Deterministic permutation model | PASS |
| 486 | Canonical permutations | Permutation 020 input order (1, 8, 16, 128, 4, 2, 32, 64) renders canonical eight-component order | Deterministic permutation model | PASS |
| 487 | Canonical permutations | Permutation 021 input order (4, 16, 64, 128, 32, 2, 1, 8) renders canonical eight-component order | Deterministic permutation model | PASS |
| 488 | Canonical permutations | Permutation 022 input order (8, 1, 32, 64, 128, 2, 4, 16) renders canonical eight-component order | Deterministic permutation model | PASS |
| 489 | Canonical permutations | Permutation 023 input order (1, 2, 128, 4, 32, 8, 16, 64) renders canonical eight-component order | Deterministic permutation model | PASS |
| 490 | Canonical permutations | Permutation 024 input order (128, 2, 4, 64, 1, 32, 8, 16) renders canonical eight-component order | Deterministic permutation model | PASS |
| 491 | Canonical permutations | Permutation 025 input order (1, 128, 8, 16, 4, 32, 64, 2) renders canonical eight-component order | Deterministic permutation model | PASS |
| 492 | Canonical permutations | Permutation 026 input order (1, 4, 8, 64, 32, 128, 16, 2) renders canonical eight-component order | Deterministic permutation model | PASS |
| 493 | Canonical permutations | Permutation 027 input order (4, 64, 128, 2, 1, 16, 8, 32) renders canonical eight-component order | Deterministic permutation model | PASS |
| 494 | Canonical permutations | Permutation 028 input order (128, 32, 4, 16, 1, 2, 64, 8) renders canonical eight-component order | Deterministic permutation model | PASS |
| 495 | Canonical permutations | Permutation 029 input order (1, 16, 128, 8, 32, 4, 64, 2) renders canonical eight-component order | Deterministic permutation model | PASS |
| 496 | Canonical permutations | Permutation 030 input order (32, 128, 8, 1, 16, 2, 4, 64) renders canonical eight-component order | Deterministic permutation model | PASS |
| 497 | Canonical permutations | Permutation 031 input order (128, 64, 2, 1, 8, 16, 32, 4) renders canonical eight-component order | Deterministic permutation model | PASS |
| 498 | Canonical permutations | Permutation 032 input order (8, 16, 64, 32, 128, 1, 2, 4) renders canonical eight-component order | Deterministic permutation model | PASS |
| 499 | Canonical permutations | Permutation 033 input order (128, 16, 4, 32, 64, 1, 8, 2) renders canonical eight-component order | Deterministic permutation model | PASS |
| 500 | Canonical permutations | Permutation 034 input order (16, 8, 128, 4, 2, 32, 1, 64) renders canonical eight-component order | Deterministic permutation model | PASS |
| 501 | Canonical permutations | Permutation 035 input order (4, 1, 128, 32, 8, 2, 16, 64) renders canonical eight-component order | Deterministic permutation model | PASS |
| 502 | Canonical permutations | Permutation 036 input order (32, 64, 128, 8, 4, 2, 1, 16) renders canonical eight-component order | Deterministic permutation model | PASS |
| 503 | Canonical permutations | Permutation 037 input order (64, 8, 4, 1, 128, 2, 16, 32) renders canonical eight-component order | Deterministic permutation model | PASS |
| 504 | Canonical permutations | Permutation 038 input order (128, 1, 8, 32, 64, 2, 16, 4) renders canonical eight-component order | Deterministic permutation model | PASS |
| 505 | Canonical permutations | Permutation 039 input order (2, 32, 16, 4, 64, 128, 8, 1) renders canonical eight-component order | Deterministic permutation model | PASS |
| 506 | Canonical permutations | Permutation 040 input order (128, 16, 2, 64, 1, 4, 8, 32) renders canonical eight-component order | Deterministic permutation model | PASS |
| 507 | Canonical permutations | Permutation 041 input order (128, 8, 1, 64, 4, 2, 16, 32) renders canonical eight-component order | Deterministic permutation model | PASS |
| 508 | Canonical permutations | Permutation 042 input order (128, 2, 32, 16, 64, 4, 8, 1) renders canonical eight-component order | Deterministic permutation model | PASS |
| 509 | Canonical permutations | Permutation 043 input order (32, 64, 128, 4, 1, 16, 8, 2) renders canonical eight-component order | Deterministic permutation model | PASS |
| 510 | Canonical permutations | Permutation 044 input order (2, 64, 8, 32, 1, 16, 128, 4) renders canonical eight-component order | Deterministic permutation model | PASS |
| 511 | Canonical permutations | Permutation 045 input order (8, 16, 128, 2, 4, 1, 64, 32) renders canonical eight-component order | Deterministic permutation model | PASS |
| 512 | Canonical permutations | Permutation 046 input order (4, 128, 16, 2, 1, 8, 32, 64) renders canonical eight-component order | Deterministic permutation model | PASS |
| 513 | Canonical permutations | Permutation 047 input order (16, 2, 1, 32, 8, 4, 64, 128) renders canonical eight-component order | Deterministic permutation model | PASS |
| 514 | Canonical permutations | Permutation 048 input order (16, 2, 128, 32, 1, 4, 64, 8) renders canonical eight-component order | Deterministic permutation model | PASS |
| 515 | Canonical permutations | Permutation 049 input order (4, 1, 64, 128, 8, 2, 16, 32) renders canonical eight-component order | Deterministic permutation model | PASS |
| 516 | Canonical permutations | Permutation 050 input order (16, 4, 2, 64, 32, 128, 1, 8) renders canonical eight-component order | Deterministic permutation model | PASS |
| 517 | Canonical permutations | Permutation 051 input order (2, 1, 4, 16, 8, 128, 64, 32) renders canonical eight-component order | Deterministic permutation model | PASS |
| 518 | Canonical permutations | Permutation 052 input order (64, 2, 32, 128, 1, 8, 4, 16) renders canonical eight-component order | Deterministic permutation model | PASS |
| 519 | Canonical permutations | Permutation 053 input order (64, 16, 32, 128, 8, 2, 4, 1) renders canonical eight-component order | Deterministic permutation model | PASS |
| 520 | Canonical permutations | Permutation 054 input order (2, 128, 16, 4, 1, 32, 8, 64) renders canonical eight-component order | Deterministic permutation model | PASS |
| 521 | Canonical permutations | Permutation 055 input order (128, 64, 16, 1, 2, 8, 32, 4) renders canonical eight-component order | Deterministic permutation model | PASS |
| 522 | Canonical permutations | Permutation 056 input order (32, 64, 8, 1, 128, 16, 4, 2) renders canonical eight-component order | Deterministic permutation model | PASS |
| 523 | Canonical permutations | Permutation 057 input order (8, 4, 128, 2, 32, 64, 1, 16) renders canonical eight-component order | Deterministic permutation model | PASS |
| 524 | Canonical permutations | Permutation 058 input order (2, 1, 16, 64, 32, 8, 128, 4) renders canonical eight-component order | Deterministic permutation model | PASS |
| 525 | Canonical permutations | Permutation 059 input order (128, 32, 16, 64, 4, 2, 8, 1) renders canonical eight-component order | Deterministic permutation model | PASS |
| 526 | Canonical permutations | Permutation 060 input order (2, 32, 16, 4, 1, 64, 128, 8) renders canonical eight-component order | Deterministic permutation model | PASS |
| 527 | Canonical permutations | Permutation 061 input order (8, 64, 16, 4, 32, 128, 1, 2) renders canonical eight-component order | Deterministic permutation model | PASS |
| 528 | Canonical permutations | Permutation 062 input order (32, 16, 1, 8, 4, 64, 2, 128) renders canonical eight-component order | Deterministic permutation model | PASS |
| 529 | Canonical permutations | Permutation 063 input order (1, 32, 2, 64, 16, 4, 128, 8) renders canonical eight-component order | Deterministic permutation model | PASS |
| 530 | Canonical permutations | Permutation 064 input order (64, 128, 8, 2, 32, 4, 1, 16) renders canonical eight-component order | Deterministic permutation model | PASS |
| 531 | Canonical permutations | Permutation 065 input order (64, 8, 4, 32, 128, 16, 2, 1) renders canonical eight-component order | Deterministic permutation model | PASS |
| 532 | Canonical permutations | Permutation 066 input order (1, 2, 16, 64, 32, 128, 8, 4) renders canonical eight-component order | Deterministic permutation model | PASS |
| 533 | Canonical permutations | Permutation 067 input order (1, 16, 128, 8, 64, 32, 4, 2) renders canonical eight-component order | Deterministic permutation model | PASS |
| 534 | Canonical permutations | Permutation 068 input order (8, 32, 16, 4, 1, 128, 2, 64) renders canonical eight-component order | Deterministic permutation model | PASS |
| 535 | Canonical permutations | Permutation 069 input order (8, 32, 128, 16, 4, 64, 2, 1) renders canonical eight-component order | Deterministic permutation model | PASS |
| 536 | Canonical permutations | Permutation 070 input order (64, 1, 2, 32, 4, 8, 128, 16) renders canonical eight-component order | Deterministic permutation model | PASS |
| 537 | Canonical permutations | Permutation 071 input order (128, 1, 64, 16, 2, 4, 8, 32) renders canonical eight-component order | Deterministic permutation model | PASS |
| 538 | Canonical permutations | Permutation 072 input order (64, 16, 32, 1, 128, 4, 8, 2) renders canonical eight-component order | Deterministic permutation model | PASS |
| 539 | Canonical permutations | Permutation 073 input order (2, 128, 8, 1, 64, 4, 32, 16) renders canonical eight-component order | Deterministic permutation model | PASS |
| 540 | Canonical permutations | Permutation 074 input order (4, 32, 1, 2, 16, 64, 128, 8) renders canonical eight-component order | Deterministic permutation model | PASS |
| 541 | Canonical permutations | Permutation 075 input order (16, 128, 32, 8, 64, 1, 2, 4) renders canonical eight-component order | Deterministic permutation model | PASS |
| 542 | Canonical permutations | Permutation 076 input order (8, 128, 1, 2, 16, 4, 32, 64) renders canonical eight-component order | Deterministic permutation model | PASS |
| 543 | Canonical permutations | Permutation 077 input order (4, 32, 128, 2, 1, 8, 64, 16) renders canonical eight-component order | Deterministic permutation model | PASS |
| 544 | Canonical permutations | Permutation 078 input order (8, 16, 128, 32, 4, 2, 1, 64) renders canonical eight-component order | Deterministic permutation model | PASS |
| 545 | Canonical permutations | Permutation 079 input order (32, 8, 128, 1, 64, 16, 2, 4) renders canonical eight-component order | Deterministic permutation model | PASS |
| 546 | Canonical permutations | Permutation 080 input order (128, 4, 2, 16, 32, 64, 8, 1) renders canonical eight-component order | Deterministic permutation model | PASS |
| 547 | Canonical permutations | Permutation 081 input order (128, 1, 32, 4, 16, 8, 64, 2) renders canonical eight-component order | Deterministic permutation model | PASS |
| 548 | Canonical permutations | Permutation 082 input order (16, 4, 2, 8, 128, 32, 64, 1) renders canonical eight-component order | Deterministic permutation model | PASS |
| 549 | Canonical permutations | Permutation 083 input order (1, 8, 128, 64, 2, 32, 4, 16) renders canonical eight-component order | Deterministic permutation model | PASS |
| 550 | Canonical permutations | Permutation 084 input order (2, 128, 32, 1, 64, 8, 4, 16) renders canonical eight-component order | Deterministic permutation model | PASS |
| 551 | Canonical permutations | Permutation 085 input order (32, 2, 8, 1, 64, 4, 16, 128) renders canonical eight-component order | Deterministic permutation model | PASS |
| 552 | Canonical permutations | Permutation 086 input order (1, 2, 64, 16, 32, 4, 128, 8) renders canonical eight-component order | Deterministic permutation model | PASS |
| 553 | Canonical permutations | Permutation 087 input order (64, 4, 2, 32, 8, 1, 128, 16) renders canonical eight-component order | Deterministic permutation model | PASS |
| 554 | Canonical permutations | Permutation 088 input order (128, 64, 4, 2, 16, 1, 8, 32) renders canonical eight-component order | Deterministic permutation model | PASS |
| 555 | Canonical permutations | Permutation 089 input order (128, 1, 8, 2, 64, 32, 4, 16) renders canonical eight-component order | Deterministic permutation model | PASS |
| 556 | Canonical permutations | Permutation 090 input order (64, 2, 128, 16, 1, 32, 8, 4) renders canonical eight-component order | Deterministic permutation model | PASS |
| 557 | Canonical permutations | Permutation 091 input order (2, 32, 8, 128, 64, 1, 16, 4) renders canonical eight-component order | Deterministic permutation model | PASS |
| 558 | Canonical permutations | Permutation 092 input order (32, 1, 8, 2, 16, 64, 128, 4) renders canonical eight-component order | Deterministic permutation model | PASS |
| 559 | Canonical permutations | Permutation 093 input order (1, 32, 128, 4, 16, 64, 8, 2) renders canonical eight-component order | Deterministic permutation model | PASS |
| 560 | Canonical permutations | Permutation 094 input order (16, 1, 32, 2, 64, 8, 4, 128) renders canonical eight-component order | Deterministic permutation model | PASS |
| 561 | Canonical permutations | Permutation 095 input order (8, 4, 64, 2, 16, 1, 128, 32) renders canonical eight-component order | Deterministic permutation model | PASS |
| 562 | Canonical permutations | Permutation 096 input order (32, 16, 2, 4, 1, 64, 128, 8) renders canonical eight-component order | Deterministic permutation model | PASS |
| 563 | Canonical permutations | Permutation 097 input order (4, 32, 2, 64, 128, 16, 1, 8) renders canonical eight-component order | Deterministic permutation model | PASS |
| 564 | Canonical permutations | Permutation 098 input order (64, 2, 128, 8, 32, 16, 4, 1) renders canonical eight-component order | Deterministic permutation model | PASS |
| 565 | Canonical permutations | Permutation 099 input order (4, 8, 32, 2, 128, 1, 64, 16) renders canonical eight-component order | Deterministic permutation model | PASS |
| 566 | Canonical permutations | Permutation 100 input order (64, 4, 2, 128, 32, 8, 16, 1) renders canonical eight-component order | Deterministic permutation model | PASS |
| 567 | Canonical permutations | Permutation 101 input order (8, 16, 32, 128, 1, 4, 64, 2) renders canonical eight-component order | Deterministic permutation model | PASS |
| 568 | Canonical permutations | Permutation 102 input order (16, 32, 128, 1, 4, 8, 64, 2) renders canonical eight-component order | Deterministic permutation model | PASS |
| 569 | Canonical permutations | Permutation 103 input order (4, 64, 16, 8, 32, 1, 128, 2) renders canonical eight-component order | Deterministic permutation model | PASS |
| 570 | Canonical permutations | Permutation 104 input order (1, 64, 16, 2, 32, 8, 128, 4) renders canonical eight-component order | Deterministic permutation model | PASS |
| 571 | Canonical permutations | Permutation 105 input order (16, 4, 1, 32, 128, 8, 64, 2) renders canonical eight-component order | Deterministic permutation model | PASS |
| 572 | Canonical permutations | Permutation 106 input order (4, 32, 128, 8, 64, 1, 2, 16) renders canonical eight-component order | Deterministic permutation model | PASS |
| 573 | Canonical permutations | Permutation 107 input order (4, 1, 64, 8, 2, 16, 32, 128) renders canonical eight-component order | Deterministic permutation model | PASS |
| 574 | Canonical permutations | Permutation 108 input order (16, 64, 1, 32, 8, 128, 4, 2) renders canonical eight-component order | Deterministic permutation model | PASS |
| 575 | Canonical permutations | Permutation 109 input order (64, 32, 2, 8, 1, 128, 4, 16) renders canonical eight-component order | Deterministic permutation model | PASS |
| 576 | Canonical permutations | Permutation 110 input order (4, 32, 2, 128, 1, 16, 64, 8) renders canonical eight-component order | Deterministic permutation model | PASS |
| 577 | Canonical permutations | Permutation 111 input order (2, 16, 1, 128, 32, 64, 8, 4) renders canonical eight-component order | Deterministic permutation model | PASS |
| 578 | Canonical permutations | Permutation 112 input order (16, 1, 4, 64, 2, 128, 32, 8) renders canonical eight-component order | Deterministic permutation model | PASS |
| 579 | Canonical permutations | Permutation 113 input order (128, 8, 4, 32, 64, 1, 2, 16) renders canonical eight-component order | Deterministic permutation model | PASS |
| 580 | Canonical permutations | Permutation 114 input order (8, 2, 64, 128, 32, 1, 16, 4) renders canonical eight-component order | Deterministic permutation model | PASS |
| 581 | Canonical permutations | Permutation 115 input order (8, 1, 32, 4, 128, 16, 2, 64) renders canonical eight-component order | Deterministic permutation model | PASS |
| 582 | Canonical permutations | Permutation 116 input order (64, 128, 32, 4, 1, 16, 2, 8) renders canonical eight-component order | Deterministic permutation model | PASS |
| 583 | Canonical permutations | Permutation 117 input order (32, 128, 16, 2, 1, 64, 8, 4) renders canonical eight-component order | Deterministic permutation model | PASS |
| 584 | Canonical permutations | Permutation 118 input order (2, 32, 4, 8, 1, 128, 16, 64) renders canonical eight-component order | Deterministic permutation model | PASS |
| 585 | Canonical permutations | Permutation 119 input order (4, 8, 32, 16, 1, 64, 128, 2) renders canonical eight-component order | Deterministic permutation model | PASS |
| 586 | Canonical permutations | Permutation 120 input order (8, 4, 64, 2, 32, 1, 128, 16) renders canonical eight-component order | Deterministic permutation model | PASS |
| 587 | Canonical permutations | Permutation 121 input order (4, 128, 32, 8, 16, 1, 64, 2) renders canonical eight-component order | Deterministic permutation model | PASS |
| 588 | Canonical permutations | Permutation 122 input order (64, 1, 32, 8, 128, 2, 4, 16) renders canonical eight-component order | Deterministic permutation model | PASS |
| 589 | Canonical permutations | Permutation 123 input order (64, 16, 32, 1, 2, 128, 8, 4) renders canonical eight-component order | Deterministic permutation model | PASS |
| 590 | Canonical permutations | Permutation 124 input order (1, 16, 64, 128, 2, 32, 8, 4) renders canonical eight-component order | Deterministic permutation model | PASS |
| 591 | Canonical permutations | Permutation 125 input order (2, 8, 128, 32, 1, 64, 16, 4) renders canonical eight-component order | Deterministic permutation model | PASS |
| 592 | Canonical permutations | Permutation 126 input order (4, 32, 64, 128, 2, 8, 1, 16) renders canonical eight-component order | Deterministic permutation model | PASS |
| 593 | Canonical permutations | Permutation 127 input order (8, 32, 4, 128, 64, 16, 1, 2) renders canonical eight-component order | Deterministic permutation model | PASS |
| 594 | Canonical permutations | Permutation 128 input order (4, 8, 16, 2, 128, 32, 1, 64) renders canonical eight-component order | Deterministic permutation model | PASS |
| 595 | No partial section | Missing Application Data returns nil section rather than seven-line output | Deterministic model | PASS |
| 596 | No partial section | Missing Profile App Data returns nil section rather than seven-line output | Deterministic model | PASS |
| 597 | No partial section | Missing Global Safari returns nil section rather than seven-line output | Deterministic model | PASS |
| 598 | No partial section | Missing App Groups returns nil section rather than seven-line output | Deterministic model | PASS |
| 599 | No partial section | Missing System Global returns nil section rather than seven-line output | Deterministic model | PASS |
| 600 | No partial section | Missing Shared System Databases returns nil section rather than seven-line output | Deterministic model | PASS |
| 601 | No partial section | Missing Preferences returns nil section rather than seven-line output | Deterministic model | PASS |
| 602 | No partial section | Missing Keychain returns nil section rather than seven-line output | Deterministic model | PASS |
| 603 | No partial section | Unknown component value prevents partial section | Deterministic model | PASS |
| 604 | No partial section | Nil result prevents synthetic component section | Deterministic model | PASS |
| 605 | Warning attribution | Component section shows zero warning suffix when component warning count is zero | Source gate + deterministic message model | PASS |
| 606 | Warning attribution | Component section shows singular warning suffix for one warning | Source gate + deterministic message model | PASS |
| 607 | Warning attribution | Component section shows plural warning suffix for two warnings | Source gate + deterministic message model | PASS |
| 608 | Warning attribution | Component section supports warning count 4096 without truncation | Source gate + deterministic message model | PASS |
| 609 | Warning attribution | Component warning strings are not iterated by formatter | Source gate + deterministic message model | PASS |
| 610 | Warning attribution | Component warning text is absent from component status line | Source gate + deterministic message model | PASS |
| 611 | Warning attribution | Aggregate warning helper remains the sole warning-text renderer | Source gate + deterministic message model | PASS |
| 612 | Warning attribution | Aggregate warning order is preserved | Source gate + deterministic message model | PASS |
| 613 | Warning attribution | Aggregate warning duplicates are preserved | Source gate + deterministic message model | PASS |
| 614 | Warning attribution | Same warning in component and aggregate arrays appears as count plus one aggregate text line | Source gate + deterministic message model | PASS |
| 615 | Warning attribution | Component section precedes aggregate Warnings section | Source gate + deterministic message model | PASS |
| 616 | Warning attribution | Invalid result warnings are never dereferenced for component presentation | Source gate + deterministic message model | PASS |
| 617 | Outcome integration | Restore Successful retains high-level title and gains eight component lines | Source gate + integration model | PASS |
| 618 | Outcome integration | Restore Completed with Warnings retains title and appends aggregate warnings after components | Source gate + integration model | PASS |
| 619 | Outcome integration | Restore Completed with Component Failures retains title and includes failed detail | Source gate + integration model | PASS |
| 620 | Outcome integration | Restore Failed with valid result includes component section | Source gate + integration model | PASS |
| 621 | Outcome integration | Restore Failed: Component Rollback Completed retains exact title and rollback label | Source gate + integration model | PASS |
| 622 | Outcome integration | Restore Failed: Rollback Incomplete retains exact title and incomplete label | Source gate + integration model | PASS |
| 623 | Outcome integration | Pre-result-boundary failure has no component section | Source gate + integration model | PASS |
| 624 | Outcome integration | Nil result and nil error retain TASK-5.2 fail-closed behavior without component section | Source gate + integration model | PASS |
| 625 | Outcome integration | Malformed result and nil error have no component section | Source gate + integration model | PASS |
| 626 | Outcome integration | Malformed result and error have no component section | Source gate + integration model | PASS |
| 627 | Outcome integration | Keychain warning-only failure displays Keychain Failed with Rollback Not Performed | Source gate + integration model | PASS |
| 628 | Outcome integration | Completed component rollback does not claim whole-Restore rollback | Source gate + integration model | PASS |
| 629 | Outcome integration | Incomplete rollback safety explanation remains before component results | Source gate + integration model | PASS |
| 630 | Outcome integration | All Restore outcomes continue to use copyPath nil | Source gate + integration model | PASS |
| 631 | Message placement | Primary success message precedes Component Results | Deterministic message model | PASS |
| 632 | Message placement | Primary component-failure message precedes Component Results | Deterministic message model | PASS |
| 633 | Message placement | Plain NSError description precedes Component Results | Deterministic message model | PASS |
| 634 | Message placement | Completed rollback explanation precedes Component Results | Deterministic message model | PASS |
| 635 | Message placement | Incomplete rollback explanation precedes Component Results | Deterministic message model | PASS |
| 636 | Message placement | Component Results precedes aggregate Warnings | Deterministic message model | PASS |
| 637 | Message placement | No duplicate Component Results header is emitted | Deterministic message model | PASS |
| 638 | Message placement | No trailing blank component entry is emitted | Deterministic message model | PASS |
| 639 | Message placement | Failure detail line does not begin with component bullet prefix | Deterministic message model | PASS |
| 640 | Message placement | Exactly eight component bullet lines are emitted for valid result | Deterministic message model | PASS |
| 641 | Pending/background | Foreground result presents full final component string immediately | Protected-region hash + state model | PASS |
| 642 | Pending/background | Background success queues full component section | Protected-region hash + state model | PASS |
| 643 | Pending/background | Background warning success queues aggregate warnings after components | Protected-region hash + state model | PASS |
| 644 | Pending/background | Background component failure queues failure detail | Protected-region hash + state model | PASS |
| 645 | Pending/background | Background completed rollback queues exact subtype title | Protected-region hash + state model | PASS |
| 646 | Pending/background | Background incomplete rollback queues exact safety subtype title | Protected-region hash + state model | PASS |
| 647 | Pending/background | pendingAlertMessage stores immutable final string snapshot | Protected-region hash + state model | PASS |
| 648 | Pending/background | pendingAlertTitle stores unchanged TASK-5.2 title | Protected-region hash + state model | PASS |
| 649 | Pending/background | pendingCopyPath remains nil | Protected-region hash + state model | PASS |
| 650 | Pending/background | Become-active delivery presents exact stored component order | Protected-region hash + state model | PASS |
| 651 | Pending/background | Become-active delivery clears pending message state | Protected-region hash + state model | PASS |
| 652 | Pending/background | Pending queue does not rebuild from mutable result objects | Protected-region hash + state model | PASS |
| 653 | Protected boundaries | TASK-5.1 backup presentation helper hash is unchanged | Hash/diff evidence | PASS |
| 654 | Protected boundaries | TASK-5.1 backup button method hash is unchanged | Hash/diff evidence | PASS |
| 655 | Protected boundaries | TASK-5.1 backup title literals remain one each | Hash/diff evidence | PASS |
| 656 | Protected boundaries | TASK-5.2 Restore outcome core hash is unchanged | Hash/diff evidence | PASS |
| 657 | Protected boundaries | TASK-5.2 Restore title mapper remains inside unchanged outcome core | Hash/diff evidence | PASS |
| 658 | Protected boundaries | TASK-5.2 aggregate warning helper hash is unchanged | Hash/diff evidence | PASS |
| 659 | Protected boundaries | TASK-5.2 primary message switch hash is unchanged | Hash/diff evidence | PASS |
| 660 | Protected boundaries | Pending alert region hash is unchanged | Hash/diff evidence | PASS |
| 661 | Protected boundaries | AppDataBackupManager.m is baseline-identical | Hash/diff evidence | PASS |
| 662 | Protected boundaries | PXRestoreResult.h is baseline-identical | Hash/diff evidence | PASS |
| 663 | Protected boundaries | PXRestoreResult.m is baseline-identical | Hash/diff evidence | PASS |
| 664 | Protected boundaries | PXRestorePlan sources are baseline-identical | Hash/diff evidence | PASS |
| 665 | Protected boundaries | Main transaction sources are baseline-identical | Hash/diff evidence | PASS |
| 666 | Protected boundaries | App Group transaction sources are baseline-identical | Hash/diff evidence | PASS |
| 667 | Protected boundaries | Optional transaction/staging sources are baseline-identical | Hash/diff evidence | PASS |
| 668 | Protected boundaries | ProjectXViewController.m is baseline-identical | Hash/diff evidence | PASS |
| 669 | Protected boundaries | ProfileManagerViewController.m is baseline-identical | Hash/diff evidence | PASS |
| 670 | Protected boundaries | Keychain helper sources are baseline-identical | Hash/diff evidence | PASS |
| 671 | Protected boundaries | Makefile is baseline-identical | Hash/diff evidence | PASS |
| 672 | Protected boundaries | Protected file diff set is empty | Hash/diff evidence | PASS |

## Objective-C/toolchain status
Windows static gates PASS: balanced Objective-C delimiters/braces/brackets/parentheses, exact literal counts, formatter model, 128 permutations, protected hashes, no conflict markers, no NUL, CRLF audit, and `git diff --check`. Apple `make clean`, `make`, and `make package` were not run because clang/Theos/Xcode/make are unavailable. No Apple compile/link/package PASS is claimed.

## Device/UI status
NOT RUN. No iOS device was available. Small-screen alert readability, actual UIKit wrapping, foreground presentation, background pending delivery, and physical Restore outcomes remain device-test pending.

## Full authorized diff
```diff
diff --git a/AppDataBackupRestoreViewController.m b/AppDataBackupRestoreViewController.m
index 1de96d2..98a0d94 100644
--- a/AppDataBackupRestoreViewController.m
+++ b/AppDataBackupRestoreViewController.m
@@ -358,6 +358,177 @@ static void PXAppendRestoreWarnings(NSMutableString *message,
     }
 }

+static const PXRestoreComponent PXRestorePresentationComponentOrder[] = {
+    PXRestoreComponentApplicationData,
+    PXRestoreComponentProfileAppData,
+    PXRestoreComponentGlobalSafari,
+    PXRestoreComponentAppGroups,
+    PXRestoreComponentSystemGlobal,
+    PXRestoreComponentSharedSystemDatabases,
+    PXRestoreComponentPreferences,
+    PXRestoreComponentKeychain,
+};
+
+static NSString *PXRestoreComponentDisplayName(PXRestoreComponent component) {
+    switch (component) {
+        case PXRestoreComponentApplicationData:
+            return @"Application Data";
+        case PXRestoreComponentProfileAppData:
+            return @"Profile App Data";
+        case PXRestoreComponentGlobalSafari:
+            return @"Global Safari";
+        case PXRestoreComponentAppGroups:
+            return @"App Groups";
+        case PXRestoreComponentSystemGlobal:
+            return @"System Global";
+        case PXRestoreComponentSharedSystemDatabases:
+            return @"Shared System Databases";
+        case PXRestoreComponentPreferences:
+            return @"Preferences";
+        case PXRestoreComponentKeychain:
+            return @"Keychain";
+        default:
+            return nil;
+    }
+}
+
+static NSString *PXRestoreComponentStatusDisplayName(PXRestoreComponentStatus status) {
+    switch (status) {
+        case PXRestoreComponentStatusSucceeded:
+            return @"Succeeded";
+        case PXRestoreComponentStatusSkipped:
+            return @"Skipped";
+        case PXRestoreComponentStatusNotAttempted:
+            return @"Not Attempted";
+        case PXRestoreComponentStatusFailed:
+            return @"Failed";
+        default:
+            return nil;
+    }
+}
+
+static NSString *PXRestoreRollbackDisplayName(PXRestoreRollbackStatus rollbackStatus) {
+    switch (rollbackStatus) {
+        case PXRestoreRollbackStatusNotPerformed:
+            return @"Rollback Not Performed";
+        case PXRestoreRollbackStatusCompleted:
+            return @"Rollback Completed";
+        case PXRestoreRollbackStatusIncomplete:
+            return @"Rollback Incomplete";
+        default:
+            return nil;
+    }
+}
+
+static NSString *PXRestoreUnitProgressDescription(NSUInteger committedUnitCount,
+                                                   NSUInteger plannedUnitCount) {
+    NSString *unitLabel = plannedUnitCount == 1 ? @"unit" : @"units";
+    return [NSString stringWithFormat:@"%lu/%lu %@",
+            (unsigned long)committedUnitCount,
+            (unsigned long)plannedUnitCount,
+            unitLabel];
+}
+
+static NSString *PXRestoreWarningCountDescription(NSUInteger warningCount) {
+    if (warningCount == 0) {
+        return nil;
+    }
+    if (warningCount == 1) {
+        return @"1 warning";
+    }
+    return [NSString stringWithFormat:@"%lu warnings", (unsigned long)warningCount];
+}
+
+static NSString *PXRestoreComponentResultEntry(PXRestoreComponentResult *componentResult) {
+    if ([componentResult class] != [PXRestoreComponentResult class]) {
+        return nil;
+    }
+
+    NSString *componentName = PXRestoreComponentDisplayName(componentResult.component);
+    NSString *statusName = PXRestoreComponentStatusDisplayName(componentResult.status);
+    if (componentName.length == 0 || statusName.length == 0) {
+        return nil;
+    }
+
+    if (componentResult.status == PXRestoreComponentStatusSkipped) {
+        return [NSString stringWithFormat:@"- %@: %@", componentName, statusName];
+    }
+
+    NSString *unitProgress =
+        PXRestoreUnitProgressDescription(componentResult.committedUnitCount,
+                                         componentResult.plannedUnitCount);
+    if (unitProgress.length == 0) {
+        return nil;
+    }
+
+    NSMutableArray<NSString *> *details = [NSMutableArray arrayWithObject:unitProgress];
+    if (componentResult.status == PXRestoreComponentStatusFailed) {
+        NSString *rollbackName = PXRestoreRollbackDisplayName(componentResult.rollbackStatus);
+        id failure = componentResult.failure;
+        id failureMessage = [failure class] == [PXRestoreFailure class]
+            ? [(PXRestoreFailure *)failure message]
+            : nil;
+        if (rollbackName.length == 0 ||
+            ![failureMessage isKindOfClass:[NSString class]] ||
+            [(NSString *)failureMessage length] == 0) {
+            return nil;
+        }
+        [details addObject:rollbackName];
+
+        NSString *warningCount =
+            PXRestoreWarningCountDescription(componentResult.warnings.count);
+        if (warningCount.length > 0) {
+            [details addObject:warningCount];
+        }
+
+        NSString *statusLine = [NSString stringWithFormat:@"- %@: %@ (%@)",
+                                componentName,
+                                statusName,
+                                [details componentsJoinedByString:@"; "]];
+        NSString *failureLine = [NSString stringWithFormat:@"  Failure: %@", failureMessage];
+        return [NSString stringWithFormat:@"%@\n%@", statusLine, failureLine];
+    }
+
+    NSString *warningCount =
+        PXRestoreWarningCountDescription(componentResult.warnings.count);
+    if (warningCount.length > 0) {
+        [details addObject:warningCount];
+    }
+    return [NSString stringWithFormat:@"- %@: %@ (%@)",
+            componentName,
+            statusName,
+            [details componentsJoinedByString:@"; "]];
+}
+
+static NSString *PXRestoreComponentResultsSection(PXRestoreResult *result) {
+    if (!PXRestoreResultIsValidForPresentation(result)) {
+        return nil;
+    }
+
+    NSMutableArray<NSString *> *entries = [NSMutableArray arrayWithCapacity:8];
+    NSUInteger componentCount =
+        sizeof(PXRestorePresentationComponentOrder) /
+        sizeof(PXRestorePresentationComponentOrder[0]);
+    for (NSUInteger index = 0; index < componentCount; index++) {
+        PXRestoreComponent component = PXRestorePresentationComponentOrder[index];
+        PXRestoreComponentResult *componentResult =
+            [result componentResultForComponent:component];
+        NSString *entry = PXRestoreComponentResultEntry(componentResult);
+        if (entry.length == 0) {
+            return nil;
+        }
+        [entries addObject:entry];
+    }
+
+    if (entries.count != 8) {
+        return nil;
+    }
+    NSString *header = @"Component Results:";
+    return [NSString stringWithFormat:@"\n\n%@\n%@",
+            header,
+            [entries componentsJoinedByString:@"\n"]];
+}
+
 @implementation AppDataBackupRestoreViewController

 static void PXAttemptBringProjectXToFront(void) {
@@ -885,6 +1056,14 @@ static void PXAttemptBringProjectXToFront(void) {
                                  break;
                          }

+                         if (validResult) {
+                             NSString *componentSection =
+                                 PXRestoreComponentResultsSection(result);
+                             if (componentSection.length > 0) {
+                                 [message appendString:componentSection];
+                             }
+                         }
+
                          if (validResult && result.warnings.count > 0) {
                              PXAppendRestoreWarnings(message, result.warnings);
                          }
```

The remaining authorized addition is this report. No unrelated production or coordinator file is included.

## Line-ending/NUL audit
- Controller: UTF-8 CRLF, 50116 bytes, 1090 CRLF endings, zero LF-only endings, zero lone CR, zero NUL, final newline.
- Report: UTF-8 LF, zero CRLF, zero lone CR, zero NUL, final newline.
- No broad formatting, unrelated whitespace cleanup, or controller encoding conversion.

## Residual risks
Apple compiler/linker/package validation and physical-device UI readability are pending. A standard UIAlertController message containing eight component rows can be lengthy on small screens; the task explicitly prohibited a custom scrolling/details controller, second alert, or expand/collapse UI.

## TASK-5.4 boundary
TASK-5.4 was not started. Confirmation wording, option switches, backup picker, destructive action style, and advanced-scope confirmation remain unchanged.

GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
