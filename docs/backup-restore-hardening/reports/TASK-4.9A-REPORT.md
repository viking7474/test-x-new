# TASK-4.9A Implementation Report

## Result
TASK-4.9A implementation is complete. The manager canonical-policy matcher now independently validates the complete six-fact artifact-policy contract and accepts the current canonical Keychain factory output. No TASK-5.1 or UI work was performed.

## User authority
The controlling specification states that TASK-4.9 is PASSED and COMPLETED. TASK-4.9A closes the confirmed post-commit manager regression before Phase 5.

## TASK-4.9 review-file status
`docs/backup-restore-hardening/reviews/TASK-4.9-REVIEW.md` was absent at implementation time. The user-authority declaration made this non-blocking; no review file was synthesized.

## Baseline
| Field | Value |
|---|---|
| Required baseline | `01200fb400f3268eb5caad58757e48ea34a4fc7c` |
| Expected HEAD | `01200fb phase4(task-4.9): enforce keychain backup file protection` |
| Manager baseline bytes | 238739 |
| Manager baseline SHA-256 | `96415127cff03f0261a4372f9df60fa7abe3095124261d01280480f51ba9fc29` |
| Manager baseline line endings | UTF-8 LF |
| TASK-4.9 report bytes | 269832 |
| TASK-4.9 report SHA-256 | `9c3d2614720b9e5b13d8bd803ac54622b557a89dfdb4faf5a20d060ffe9370ab` |

## Exact authorized scope
The implementation commit is restricted to exactly:
- `M AppDataBackupManager.m`
- `A docs/backup-restore-hardening/reports/TASK-4.9A-REPORT.md`
No task document, test source, Makefile change, UI change, policy-factory change, writer change, manifest change, publisher change, verifier change, helper change, bridge change, or Phase-5 change is authorized.

## Working-tree preservation
Pre-existing coordinator-owned modifications to `STATUS.md`, `ROADMAP.md`, `DECISIONS.md`, `README.md`, and pre-existing untracked review/task documents were not staged, reset, deleted, reformatted, or included in the implementation commit.

## Defect reproduction
The pre-fix manager matcher grouped Preferences and Keychain in one return branch. That branch required `ContinueWithoutWarning`, while the canonical Keychain factory emits `WarnAndContinue`. The pre-fix matcher also had zero checks for `requiredPOSIXMode` and zero checks for `dataProtectionRequirement`.

## Canonical factory evidence
`PXBackupArtifactPolicy.m` was inspected without modification. The Keychain factory output is Optional, WarnAndContinue, Reject, mode 0600, and Complete. All non-Keychain policies remain mode 0600 with Unspecified Data Protection.

## Manager matcher mismatch evidence
| Pre-fix fact | Observed |
|---|---|
| Preferences and Keychain shared case | TRUE |
| Keychain expected disposition | ContinueWithoutWarning (incorrect) |
| requiredPOSIXMode checks | 0 |
| dataProtectionRequirement checks | 0 |
| Independent factory recursion | 0 |

## Unconditional gate evidence
The manager constructs all eight policies and calls `PXBackupArtifactPolicyMatchesCanonicalKind` for all eight before artifact production. The Keychain call is present even when backup options are zero. A mismatch therefore reaches the existing generic `PXBackupErrorDomain`, code 106 construction failure before required data artifact production.

## Runtime impact
Before this fix, the confirmed mismatch could block data-only backups, App Group backups, Preferences backups, Keychain backups, profile-switching backups, and RRS workflow backups because the Keychain policy was always constructed and checked.

## Policy matrix
| Kind | Requirement | Failure disposition | Empty policy | POSIX mode | Data Protection |
|---|---|---|---|---|---|
| ApplicationData | Required | AbortBackup | Reject | 0600 | Unspecified |
| AppGroup | Optional | WarnAndContinue | Reject | 0600 | Unspecified |
| ProfileAppData | Optional | WarnAndContinue | Reject | 0600 | Unspecified |
| GlobalSafari | Optional | WarnAndContinue | Reject | 0600 | Unspecified |
| SystemGlobal | Optional | WarnAndContinue | Reject | 0600 | Unspecified |
| SharedSystemDatabase | Optional | ContinueWithoutWarning | Allow | 0600 | Unspecified |
| Preferences | Optional | ContinueWithoutWarning | Reject | 0600 | Unspecified |
| Keychain | Optional | WarnAndContinue | Reject | 0600 | Complete |

## Exact source change
Only `PXBackupArtifactPolicyMatchesCanonicalKind` changed. Preferences and Keychain now have separate branches. Every successful branch checks exact mode 0600 and exact Data Protection; the Keychain branch checks WarnAndContinue and Complete.

## Independent matcher rationale
The matcher does not call `policyForKind:` and does not compare against a factory-created policy. Expected values are written explicitly in the manager, preserving an independent invariant capable of detecting factory drift.

## Full-field validation proof
| Fact | Validation |
|---|---|
| Exact class contract | `isMemberOfClass:[PXBackupArtifactPolicy class]` retained |
| Kind | `policy.kind == expectedKind` |
| Requirement | Explicit per branch |
| Failure disposition | Explicit per branch |
| Empty-file policy | Explicit per branch |
| POSIX mode | Exact `0600` in every successful branch |
| Data Protection | Unspecified for non-Keychain; Complete for Keychain |
| Unknown kind | Falls through to `return NO` |

## Positive matrix
| Kind | Expected result |
|---|---|
| ApplicationData | PASS |
| AppGroup | PASS |
| ProfileAppData | PASS |
| GlobalSafari | PASS |
| SystemGlobal | PASS |
| SharedSystemDatabase | PASS |
| Preferences | PASS |
| Keychain | PASS |

Result: 8/8 canonical rows accepted.

## Mutation rejection matrix
| Mutation group | Cases | Result |
|---|---|---|
| Kind mismatch | 56 | 56 rejected |
| Requirement mutation | 8 | 8 rejected |
| Failure-disposition mutation | 16 | 16 rejected |
| Empty-file mutation | 8 | 8 rejected |
| POSIX-mode mutation | 40 | 40 rejected |
| Data-Protection mutation | 8 | 8 rejected |
| Unknown kind | 4 | 4 rejected |
| Deterministic fuzz | 400,000 | Exact canonical equivalence |

Total deterministic matcher/model assertions: 400,189.

## Backup smoke status
| Scenario | Deterministic model | Apple/device runtime |
|---|---|---|
| Data-only backup | Construction gate passes | PENDING |
| Data + App Groups | Construction gate passes | PENDING |
| Data + Preferences | Construction gate passes | PENDING |
| Data + Keychain | Reaches Keychain policy path | PENDING |
| Data + all options | Construction gate passes | PENDING |
| Keychain completed | Canonical gate passes | PENDING |
| Keychain partial with usable output | Canonical gate passes | PENDING |
| Keychain protection failure | WarnAndContinue omission model passes | PENDING |
| Required data failure | AbortBackup invariant passes | PENDING |
| Invalid synthetic policy | Rejected | Not required |

## Warning behavior
The exact protection warning remains once: `Keychain backup could not be protected and was omitted`. No duplicate warning, raw writer error, policy enum value, or Preferences warning behavior was added. Preferences remains silent omission.

## Error behavior
`PXBackupErrorDomain` and code 106 remain unchanged. No error code was added. Code 106 now occurs only when a policy is genuinely non-canonical; all eight current factory outputs pass the construction gate.

## Final artifact audit behavior
`PXBackupAuditVerifiedArtifactPolicies` continues to call the same matcher for all eight canonical policies. Therefore accepted Keychain records now require WarnAndContinue, Reject, 0600, and Complete, and any accepted record with a mutated protection requirement fails the final audit.

## TASK-4.9 non-regression
The TASK-4.9 protection implementation remains byte-identical: descriptor-based class-A apply/verify, exact 0600 mode, exact process ownership, single hard link, writer pre/post artifact-rename proof, publisher pre/post publication proof and rollback, revision-2 policy graph, revision-1 compatibility, and restore-stage protection upgrade.

## Keychain operation counts
| Region | SecItemCopyMatching | SecItemAdd | SecItemUpdate | SecItemDelete |
|---|---|---|---|---|
| Whole Keychain core | 6 | 1 | 1 | 1 |
| Restore | 1 | 1 | 1 | 0 |

## Protected hashes
Protected files checked: 41. Every entry remained byte-identical to baseline `01200fb400f3268eb5caad58757e48ea34a4fc7c`.
| Path | SHA-256 | Bytes | Unchanged |
|---|---|---|---|
| `AppDataBackupManager.h` | `b19c1c61e6df642468d713dede5a0c0bd0dbb6a0ac72d98ad6878d3cae1f2e75` | 1442 | TRUE |
| `AppDataBackupRestoreViewController.h` | `b470e92a732dca1c97b161f802baf1d3ea8d39706087648e7fc697b63eeba5cf` | 336 | TRUE |
| `AppDataBackupRestoreViewController.m` | `48e86f63aeeb6626858fe13fed6487ef36e128f0f0fde173120abb9108bd7a96` | 28132 | TRUE |
| `KeychainHelper/KeychainBackupHelper.h` | `7e77d560aed48f003f3d068e266dcb9589fbb8eb7bd95139b9dd8d6559eafb6c` | 4584 | TRUE |
| `KeychainHelper/KeychainBackupHelper.m` | `324fbe42dbbc60844d2c53cdacf2c329a6b5b6f945d955c25e91daf32d5c40e2` | 38587 | TRUE |
| `KeychainHelper/PXKeychainHelperExitCode.h` | `a0682225ac3ff962305c5bd967f319a4ad0aa7f5eec0a98596e04ba78b21e99a` | 784 | TRUE |
| `KeychainHelper/PXKeychainHelperResult.h` | `4c8ee54990838de08f2d75a025a5e0777e0f15fe42f25662e1b5661d871520e3` | 4083 | TRUE |
| `KeychainHelper/PXKeychainHelperResult.m` | `1d4a44fb6929743647734881052a4fead70111759390c711bb35aea622f7e1a5` | 51525 | TRUE |
| `KeychainHelper/PXKeychainItemIdentity.h` | `f0a1d1474e2b8887418900c665c0a41f0d9210f5ce5a9bb44c3081803adec9e4` | 2387 | TRUE |
| `KeychainHelper/PXKeychainItemIdentity.m` | `c639d006384271ab304b8b6eca1402331ac50962a055cf4406eca9d720df11df` | 62919 | TRUE |
| `KeychainHelper/backup_helper.m` | `897292e4c7e867ec845502315783ced9b9e5fa53427ac617510f84ba00c543f7` | 42561 | TRUE |
| `Makefile` | `b2d9ca1083f85b818f132612e792c73e94e78390ef06092db2075439af945dfa` | 9266 | TRUE |
| `PXBackupArtifactPolicy.h` | `08255fad381774a6e2b0f9e7e0c0176fd00decc141f54ba2caa7455a00e147bc` | 2013 | TRUE |
| `PXBackupArtifactPolicy.m` | `0d2083ea85bc4e7610cd3393adfb558429899a003029b4384b35056836330b3d` | 6259 | TRUE |
| `PXBackupArtifactVerifier.h` | `2cd726496b1830cc404c6e6665e73785552a39c74cdb9683a43d32221fc194cc` | 2006 | TRUE |
| `PXBackupArtifactVerifier.m` | `2c45882144f529380bf485724bdd2258a3d9dd43de232076e857f10f3d5958f9` | 46654 | TRUE |
| `PXBackupArtifactWriter.h` | `8834bbbe5834a343c1f58c9fc1c823ce68b30f5d11158f8a2a7cec45f9419012` | 3059 | TRUE |
| `PXBackupArtifactWriter.m` | `01296680380daeb92fb2fa1a9e1e46d18fd381f0e55db55f5627fc4215cc19ff` | 96014 | TRUE |
| `PXBackupDirectoryPublisher.h` | `0acc8af4a05df17b2e20319905773c0ba6350a749ed3b0204b94499c1da2e88d` | 2955 | TRUE |
| `PXBackupDirectoryPublisher.m` | `e146f716619708ab496bf08d8aca8c8736d0e4b4e3df024f1bc1e7a1a83ae2f6` | 82028 | TRUE |
| `PXBackupManifestV4.h` | `4e9c679d8d4a69f68111bb848467a7290a8760330b310ef4c2a25941612e6054` | 2354 | TRUE |
| `PXBackupManifestV4.m` | `4b757b5ef918bd0c08addbf7fecd432c6385ea04ebdce5dc713bf840c103f037` | 45136 | TRUE |
| `PXBackupManifestValidator.h` | `6bf479c032e044a89a9d028517a50692c7d95ccef35f78e92a782653a4dcc836` | 945 | TRUE |
| `PXBackupManifestValidator.m` | `8d16bdfa2f4eea1d95aec7800aacc2b1f28fcb54599a577f7ea571bc598f503b` | 91206 | TRUE |
| `PXBackupPublicationWorkspace.h` | `7ee3ce30d84edd6907cdc9fd3fb812dd768d03decb3ee0d50d464d17c4ae0851` | 1869 | TRUE |
| `PXBackupPublicationWorkspace.m` | `39974a40b4bf89f31ac9cbf1e8dfa716a94a0fd13e39d9c7539a02d14d2781f6` | 48086 | TRUE |
| `PXFileProtection.h` | `5c7163ec17f24c9ea4e0d4a53012fcb4c62e57decfb7891fdf8be72c554c8fb7` | 1095 | TRUE |
| `PXFileProtection.m` | `a6fb37302b7b32958026ba2842563769ee0098cf1007a6500763d3ce4f231947` | 11505 | TRUE |
| `PXKeychainHelperInvocationResult.h` | `7c166a99f440535a1c8810633ad9ae9176d2625d3447586dfe27b9c4cb30198a` | 2316 | TRUE |
| `PXKeychainHelperInvocationResult.m` | `ebfefa4a24417c3366b0114cb5ed2dcbc343b19b241942399b2109562a134180` | 18014 | TRUE |
| `PXOptionalRestoreStaging.h` | `3d594d5f2eb509e2fb9e87849013ec9428ef7083eb0c4b52ecffe00fa56809c3` | 4355 | TRUE |
| `PXOptionalRestoreStaging.m` | `1e3a0eabba6a5a8a90cb7cf3800476e9324ec4181be1fb51de0e0e08e2c5e39b` | 104823 | TRUE |
| `PXRestorePlan.h` | `5cc773132c009fd8eedf4069b33ab53901a530edd580e3231c9d982c60cf7643` | 4947 | TRUE |
| `PXRestorePlan.m` | `cb6f838638a06bc9858b392d123656590291555812c63e3d0ddd4f5529d0d141` | 48523 | TRUE |
| `PXRestoreResult.h` | `cb7f2f3e40b3414d329405b1802bf6a9f245f1b660ca983d04776c0af449e69d` | 4512 | TRUE |
| `PXRestoreResult.m` | `c698a854589731f0987379c324d02729f3b586fd0ac3575f9798b77d6207c2fb` | 15842 | TRUE |
| `ProfileManagerViewController.m` | `a26680aa7340f00b913950cd019245066d0854880839403346a965fbf832bb1a` | 159713 | TRUE |
| `ProjectXViewController.m` | `b7c5293dfa5d27fdc39c36f236f76306a855eaaf4e9e028f4c2111eb68146162` | 372278 | TRUE |
| `WeaponXKeychainBridge/Tweak.m` | `e0733e04eb4915a4753fe59247b17acd5e8cb7f8fa5fcf0bb8dee94f908459aa` | 21970 | TRUE |
| `docs/backup-restore-hardening/reports/TASK-4.9-REPORT.md` | `9c3d2614720b9e5b13d8bd803ac54622b557a89dfdb4faf5a20d060ffe9370ab` | 269832 | TRUE |
| `scripts/keychain_backup.sh` | `46b730b3ca28484232dc7af363bf722e7b7e0d612f54f9250397924847ba2d12` | 75266 | TRUE |

## UI/caller zero-diff proof
| Caller/UI path | Baseline diff |
|---|---|
| `AppDataBackupRestoreViewController.h` | zero |
| `AppDataBackupRestoreViewController.m` | zero |
| `ProfileManagerViewController.m` | zero |
| `ProjectXViewController.m` | zero |

No backup/restore title classifier or component UI was implemented.

## Makefile zero-diff proof
`git diff --quiet 01200fb400f3268eb5caad58757e48ea34a4fc7c -- Makefile` passed. No test source or target membership change was made.

## Full authorized diff
```diff
diff --git a/AppDataBackupManager.m b/AppDataBackupManager.m
index e106a8b..dfc3697 100644
--- a/AppDataBackupManager.m
+++ b/AppDataBackupManager.m
@@ -669,7 +669,10 @@ static BOOL PXBackupArtifactPolicyMatchesCanonicalKind(
             return policy.requirement == PXBackupArtifactRequirementRequired &&
                    policy.failureDisposition ==
                        PXBackupArtifactFailureDispositionAbortBackup &&
-                   policy.emptyFilePolicy == PXBackupArtifactEmptyFilePolicyReject;
+                   policy.emptyFilePolicy == PXBackupArtifactEmptyFilePolicyReject &&
+                   policy.requiredPOSIXMode == 0600 &&
+                   policy.dataProtectionRequirement ==
+                       PXBackupArtifactDataProtectionRequirementUnspecified;
         case PXBackupArtifactKindAppGroup:
         case PXBackupArtifactKindProfileAppData:
         case PXBackupArtifactKindGlobalSafari:
@@ -677,18 +680,34 @@ static BOOL PXBackupArtifactPolicyMatchesCanonicalKind(
             return policy.requirement == PXBackupArtifactRequirementOptional &&
                    policy.failureDisposition ==
                        PXBackupArtifactFailureDispositionWarnAndContinue &&
-                   policy.emptyFilePolicy == PXBackupArtifactEmptyFilePolicyReject;
+                   policy.emptyFilePolicy == PXBackupArtifactEmptyFilePolicyReject &&
+                   policy.requiredPOSIXMode == 0600 &&
+                   policy.dataProtectionRequirement ==
+                       PXBackupArtifactDataProtectionRequirementUnspecified;
         case PXBackupArtifactKindSharedSystemDatabase:
             return policy.requirement == PXBackupArtifactRequirementOptional &&
                    policy.failureDisposition ==
                        PXBackupArtifactFailureDispositionContinueWithoutWarning &&
-                   policy.emptyFilePolicy == PXBackupArtifactEmptyFilePolicyAllow;
+                   policy.emptyFilePolicy == PXBackupArtifactEmptyFilePolicyAllow &&
+                   policy.requiredPOSIXMode == 0600 &&
+                   policy.dataProtectionRequirement ==
+                       PXBackupArtifactDataProtectionRequirementUnspecified;
         case PXBackupArtifactKindPreferences:
-        case PXBackupArtifactKindKeychain:
             return policy.requirement == PXBackupArtifactRequirementOptional &&
                    policy.failureDisposition ==
                        PXBackupArtifactFailureDispositionContinueWithoutWarning &&
-                   policy.emptyFilePolicy == PXBackupArtifactEmptyFilePolicyReject;
+                   policy.emptyFilePolicy == PXBackupArtifactEmptyFilePolicyReject &&
+                   policy.requiredPOSIXMode == 0600 &&
+                   policy.dataProtectionRequirement ==
+                       PXBackupArtifactDataProtectionRequirementUnspecified;
+        case PXBackupArtifactKindKeychain:
+            return policy.requirement == PXBackupArtifactRequirementOptional &&
+                   policy.failureDisposition ==
+                       PXBackupArtifactFailureDispositionWarnAndContinue &&
+                   policy.emptyFilePolicy == PXBackupArtifactEmptyFilePolicyReject &&
+                   policy.requiredPOSIXMode == 0600 &&
+                   policy.dataProtectionRequirement ==
+                       PXBackupArtifactDataProtectionRequirementComplete;
     }
     return NO;
 }
```

## Static gates
| Gate | Result |
|---|---|
| Baseline HEAD | PASS |
| Matcher-only source delta | PASS |
| Preferences branch separate | PASS |
| Keychain branch separate | PASS |
| Shared Preferences+Keychain case | 0 |
| Keychain WarnAndContinue | PASS |
| Keychain ContinueWithoutWarning | absent |
| Keychain Complete | PASS |
| Keychain Unspecified | absent |
| Preferences ContinueWithoutWarning | PASS |
| Preferences Unspecified | PASS |
| Mode 0600 covers all eight kinds | PASS |
| Unknown kind returns NO | PASS |
| Matcher factory recursion | 0 |
| policyForKind inside matcher | 0 |
| 8/8 canonical positives | PASS |
| Mutation rejection | PASS |
| 400,000 deterministic fuzz | PASS |
| 41 protected hashes | PASS |
| UI/caller zero diff | PASS |
| TASK-4.9 report zero diff | PASS |
| Makefile zero diff | PASS |
| Keychain operation counts | PASS |
| Warning count/text | PASS |
| Error domain/code 106 | PASS |
| Git diff check | PASS |
| Git Bash syntax, two installations | PASS |

## Explicit scenarios
Explicit scenarios: 420.
| # | Group | Scenario | Expected | Result |
|---|---|---|---|---|
| 1 | Baseline reproduction | HEAD equals required baseline | Confirmed | PASS |
| 2 | Baseline reproduction | Expected TASK-4.9 commit is current | Confirmed | PASS |
| 3 | Baseline reproduction | TASK-4.9 user authority accepted | Confirmed | PASS |
| 4 | Baseline reproduction | Missing TASK-4.9 review is non-blocking | Confirmed | PASS |
| 5 | Baseline reproduction | Manager baseline size matches | Confirmed | PASS |
| 6 | Baseline reproduction | Manager baseline hash matches | Confirmed | PASS |
| 7 | Baseline reproduction | TASK-4.9 report size matches | Confirmed | PASS |
| 8 | Baseline reproduction | TASK-4.9 report hash matches | Confirmed | PASS |
| 9 | Baseline reproduction | Manager uses UTF-8 LF | Confirmed | PASS |
| 10 | Baseline reproduction | Coordinator docs are pre-existing | Confirmed | PASS |
| 11 | Baseline reproduction | No production delta before S2 | Confirmed | PASS |
| 12 | Baseline reproduction | Factory Keychain is Optional | Confirmed | PASS |
| 13 | Baseline reproduction | Factory Keychain is WarnAndContinue | Confirmed | PASS |
| 14 | Baseline reproduction | Factory Keychain rejects empty | Confirmed | PASS |
| 15 | Baseline reproduction | Factory mode is 0600 | Confirmed | PASS |
| 16 | Baseline reproduction | Factory Keychain protection is Complete | Confirmed | PASS |
| 17 | Baseline reproduction | Pre-fix matcher shares Preferences and Keychain | Confirmed | PASS |
| 18 | Baseline reproduction | Pre-fix Keychain expects ContinueWithoutWarning | Confirmed | PASS |
| 19 | Baseline reproduction | Pre-fix matcher omits POSIX mode | Confirmed | PASS |
| 20 | Baseline reproduction | Pre-fix matcher omits Data Protection | Confirmed | PASS |
| 21 | Baseline reproduction | Construction gate checks all eight | Confirmed | PASS |
| 22 | Baseline reproduction | Construction gate checks Keychain with options zero | Confirmed | PASS |
| 23 | Baseline reproduction | Mismatch maps to code 106 | Confirmed | PASS |
| 24 | Baseline reproduction | Final audit reuses matcher | Confirmed | PASS |
| 25 | Baseline reproduction | Regression impacts data-only flow | Confirmed | PASS |
| 26 | Baseline reproduction | Regression impacts Preferences flow | Confirmed | PASS |
| 27 | Baseline reproduction | Regression impacts Keychain flow | Confirmed | PASS |
| 28 | Baseline reproduction | Regression impacts profile switching | Confirmed | PASS |
| 29 | Baseline reproduction | Regression impacts RRS | Confirmed | PASS |
| 30 | Canonical positive | ApplicationData | YES | PASS |
| 31 | Canonical positive | AppGroup | YES | PASS |
| 32 | Canonical positive | ProfileAppData | YES | PASS |
| 33 | Canonical positive | GlobalSafari | YES | PASS |
| 34 | Canonical positive | SystemGlobal | YES | PASS |
| 35 | Canonical positive | SharedSystemDatabase | YES | PASS |
| 36 | Canonical positive | Preferences | YES | PASS |
| 37 | Canonical positive | Keychain | YES | PASS |
| 38 | Kind mismatch | ApplicationData policy checked as AppGroup | NO | PASS |
| 39 | Kind mismatch | ApplicationData policy checked as ProfileAppData | NO | PASS |
| 40 | Kind mismatch | ApplicationData policy checked as GlobalSafari | NO | PASS |
| 41 | Kind mismatch | ApplicationData policy checked as SystemGlobal | NO | PASS |
| 42 | Kind mismatch | ApplicationData policy checked as SharedSystemDatabase | NO | PASS |
| 43 | Kind mismatch | ApplicationData policy checked as Preferences | NO | PASS |
| 44 | Kind mismatch | ApplicationData policy checked as Keychain | NO | PASS |
| 45 | Kind mismatch | AppGroup policy checked as ApplicationData | NO | PASS |
| 46 | Kind mismatch | AppGroup policy checked as ProfileAppData | NO | PASS |
| 47 | Kind mismatch | AppGroup policy checked as GlobalSafari | NO | PASS |
| 48 | Kind mismatch | AppGroup policy checked as SystemGlobal | NO | PASS |
| 49 | Kind mismatch | AppGroup policy checked as SharedSystemDatabase | NO | PASS |
| 50 | Kind mismatch | AppGroup policy checked as Preferences | NO | PASS |
| 51 | Kind mismatch | AppGroup policy checked as Keychain | NO | PASS |
| 52 | Kind mismatch | ProfileAppData policy checked as ApplicationData | NO | PASS |
| 53 | Kind mismatch | ProfileAppData policy checked as AppGroup | NO | PASS |
| 54 | Kind mismatch | ProfileAppData policy checked as GlobalSafari | NO | PASS |
| 55 | Kind mismatch | ProfileAppData policy checked as SystemGlobal | NO | PASS |
| 56 | Kind mismatch | ProfileAppData policy checked as SharedSystemDatabase | NO | PASS |
| 57 | Kind mismatch | ProfileAppData policy checked as Preferences | NO | PASS |
| 58 | Kind mismatch | ProfileAppData policy checked as Keychain | NO | PASS |
| 59 | Kind mismatch | GlobalSafari policy checked as ApplicationData | NO | PASS |
| 60 | Kind mismatch | GlobalSafari policy checked as AppGroup | NO | PASS |
| 61 | Kind mismatch | GlobalSafari policy checked as ProfileAppData | NO | PASS |
| 62 | Kind mismatch | GlobalSafari policy checked as SystemGlobal | NO | PASS |
| 63 | Kind mismatch | GlobalSafari policy checked as SharedSystemDatabase | NO | PASS |
| 64 | Kind mismatch | GlobalSafari policy checked as Preferences | NO | PASS |
| 65 | Kind mismatch | GlobalSafari policy checked as Keychain | NO | PASS |
| 66 | Kind mismatch | SystemGlobal policy checked as ApplicationData | NO | PASS |
| 67 | Kind mismatch | SystemGlobal policy checked as AppGroup | NO | PASS |
| 68 | Kind mismatch | SystemGlobal policy checked as ProfileAppData | NO | PASS |
| 69 | Kind mismatch | SystemGlobal policy checked as GlobalSafari | NO | PASS |
| 70 | Kind mismatch | SystemGlobal policy checked as SharedSystemDatabase | NO | PASS |
| 71 | Kind mismatch | SystemGlobal policy checked as Preferences | NO | PASS |
| 72 | Kind mismatch | SystemGlobal policy checked as Keychain | NO | PASS |
| 73 | Kind mismatch | SharedSystemDatabase policy checked as ApplicationData | NO | PASS |
| 74 | Kind mismatch | SharedSystemDatabase policy checked as AppGroup | NO | PASS |
| 75 | Kind mismatch | SharedSystemDatabase policy checked as ProfileAppData | NO | PASS |
| 76 | Kind mismatch | SharedSystemDatabase policy checked as GlobalSafari | NO | PASS |
| 77 | Kind mismatch | SharedSystemDatabase policy checked as SystemGlobal | NO | PASS |
| 78 | Kind mismatch | SharedSystemDatabase policy checked as Preferences | NO | PASS |
| 79 | Kind mismatch | SharedSystemDatabase policy checked as Keychain | NO | PASS |
| 80 | Kind mismatch | Preferences policy checked as ApplicationData | NO | PASS |
| 81 | Kind mismatch | Preferences policy checked as AppGroup | NO | PASS |
| 82 | Kind mismatch | Preferences policy checked as ProfileAppData | NO | PASS |
| 83 | Kind mismatch | Preferences policy checked as GlobalSafari | NO | PASS |
| 84 | Kind mismatch | Preferences policy checked as SystemGlobal | NO | PASS |
| 85 | Kind mismatch | Preferences policy checked as SharedSystemDatabase | NO | PASS |
| 86 | Kind mismatch | Preferences policy checked as Keychain | NO | PASS |
| 87 | Kind mismatch | Keychain policy checked as ApplicationData | NO | PASS |
| 88 | Kind mismatch | Keychain policy checked as AppGroup | NO | PASS |
| 89 | Kind mismatch | Keychain policy checked as ProfileAppData | NO | PASS |
| 90 | Kind mismatch | Keychain policy checked as GlobalSafari | NO | PASS |
| 91 | Kind mismatch | Keychain policy checked as SystemGlobal | NO | PASS |
| 92 | Kind mismatch | Keychain policy checked as SharedSystemDatabase | NO | PASS |
| 93 | Kind mismatch | Keychain policy checked as Preferences | NO | PASS |
| 94 | Requirement mutation | ApplicationData | NO | PASS |
| 95 | Requirement mutation | AppGroup | NO | PASS |
| 96 | Requirement mutation | ProfileAppData | NO | PASS |
| 97 | Requirement mutation | GlobalSafari | NO | PASS |
| 98 | Requirement mutation | SystemGlobal | NO | PASS |
| 99 | Requirement mutation | SharedSystemDatabase | NO | PASS |
| 100 | Requirement mutation | Preferences | NO | PASS |
| 101 | Requirement mutation | Keychain | NO | PASS |
| 102 | Disposition mutation | ApplicationData -> WarnAndContinue | NO | PASS |
| 103 | Disposition mutation | ApplicationData -> ContinueWithoutWarning | NO | PASS |
| 104 | Disposition mutation | AppGroup -> AbortBackup | NO | PASS |
| 105 | Disposition mutation | AppGroup -> ContinueWithoutWarning | NO | PASS |
| 106 | Disposition mutation | ProfileAppData -> AbortBackup | NO | PASS |
| 107 | Disposition mutation | ProfileAppData -> ContinueWithoutWarning | NO | PASS |
| 108 | Disposition mutation | GlobalSafari -> AbortBackup | NO | PASS |
| 109 | Disposition mutation | GlobalSafari -> ContinueWithoutWarning | NO | PASS |
| 110 | Disposition mutation | SystemGlobal -> AbortBackup | NO | PASS |
| 111 | Disposition mutation | SystemGlobal -> ContinueWithoutWarning | NO | PASS |
| 112 | Disposition mutation | SharedSystemDatabase -> AbortBackup | NO | PASS |
| 113 | Disposition mutation | SharedSystemDatabase -> WarnAndContinue | NO | PASS |
| 114 | Disposition mutation | Preferences -> AbortBackup | NO | PASS |
| 115 | Disposition mutation | Preferences -> WarnAndContinue | NO | PASS |
| 116 | Disposition mutation | Keychain -> AbortBackup | NO | PASS |
| 117 | Disposition mutation | Keychain -> ContinueWithoutWarning | NO | PASS |
| 118 | Empty-policy mutation | ApplicationData | NO | PASS |
| 119 | Empty-policy mutation | AppGroup | NO | PASS |
| 120 | Empty-policy mutation | ProfileAppData | NO | PASS |
| 121 | Empty-policy mutation | GlobalSafari | NO | PASS |
| 122 | Empty-policy mutation | SystemGlobal | NO | PASS |
| 123 | Empty-policy mutation | SharedSystemDatabase | NO | PASS |
| 124 | Empty-policy mutation | Preferences | NO | PASS |
| 125 | Empty-policy mutation | Keychain | NO | PASS |
| 126 | POSIX-mode mutation | ApplicationData -> 0 | NO | PASS |
| 127 | POSIX-mode mutation | ApplicationData -> 0400 | NO | PASS |
| 128 | POSIX-mode mutation | ApplicationData -> 0644 | NO | PASS |
| 129 | POSIX-mode mutation | ApplicationData -> 0660 | NO | PASS |
| 130 | POSIX-mode mutation | ApplicationData -> 0777 | NO | PASS |
| 131 | POSIX-mode mutation | AppGroup -> 0 | NO | PASS |
| 132 | POSIX-mode mutation | AppGroup -> 0400 | NO | PASS |
| 133 | POSIX-mode mutation | AppGroup -> 0644 | NO | PASS |
| 134 | POSIX-mode mutation | AppGroup -> 0660 | NO | PASS |
| 135 | POSIX-mode mutation | AppGroup -> 0777 | NO | PASS |
| 136 | POSIX-mode mutation | ProfileAppData -> 0 | NO | PASS |
| 137 | POSIX-mode mutation | ProfileAppData -> 0400 | NO | PASS |
| 138 | POSIX-mode mutation | ProfileAppData -> 0644 | NO | PASS |
| 139 | POSIX-mode mutation | ProfileAppData -> 0660 | NO | PASS |
| 140 | POSIX-mode mutation | ProfileAppData -> 0777 | NO | PASS |
| 141 | POSIX-mode mutation | GlobalSafari -> 0 | NO | PASS |
| 142 | POSIX-mode mutation | GlobalSafari -> 0400 | NO | PASS |
| 143 | POSIX-mode mutation | GlobalSafari -> 0644 | NO | PASS |
| 144 | POSIX-mode mutation | GlobalSafari -> 0660 | NO | PASS |
| 145 | POSIX-mode mutation | GlobalSafari -> 0777 | NO | PASS |
| 146 | POSIX-mode mutation | SystemGlobal -> 0 | NO | PASS |
| 147 | POSIX-mode mutation | SystemGlobal -> 0400 | NO | PASS |
| 148 | POSIX-mode mutation | SystemGlobal -> 0644 | NO | PASS |
| 149 | POSIX-mode mutation | SystemGlobal -> 0660 | NO | PASS |
| 150 | POSIX-mode mutation | SystemGlobal -> 0777 | NO | PASS |
| 151 | POSIX-mode mutation | SharedSystemDatabase -> 0 | NO | PASS |
| 152 | POSIX-mode mutation | SharedSystemDatabase -> 0400 | NO | PASS |
| 153 | POSIX-mode mutation | SharedSystemDatabase -> 0644 | NO | PASS |
| 154 | POSIX-mode mutation | SharedSystemDatabase -> 0660 | NO | PASS |
| 155 | POSIX-mode mutation | SharedSystemDatabase -> 0777 | NO | PASS |
| 156 | POSIX-mode mutation | Preferences -> 0 | NO | PASS |
| 157 | POSIX-mode mutation | Preferences -> 0400 | NO | PASS |
| 158 | POSIX-mode mutation | Preferences -> 0644 | NO | PASS |
| 159 | POSIX-mode mutation | Preferences -> 0660 | NO | PASS |
| 160 | POSIX-mode mutation | Preferences -> 0777 | NO | PASS |
| 161 | POSIX-mode mutation | Keychain -> 0 | NO | PASS |
| 162 | POSIX-mode mutation | Keychain -> 0400 | NO | PASS |
| 163 | POSIX-mode mutation | Keychain -> 0644 | NO | PASS |
| 164 | POSIX-mode mutation | Keychain -> 0660 | NO | PASS |
| 165 | POSIX-mode mutation | Keychain -> 0777 | NO | PASS |
| 166 | Protection mutation | ApplicationData | NO | PASS |
| 167 | Protection mutation | AppGroup | NO | PASS |
| 168 | Protection mutation | ProfileAppData | NO | PASS |
| 169 | Protection mutation | GlobalSafari | NO | PASS |
| 170 | Protection mutation | SystemGlobal | NO | PASS |
| 171 | Protection mutation | SharedSystemDatabase | NO | PASS |
| 172 | Protection mutation | Preferences | NO | PASS |
| 173 | Protection mutation | Keychain | NO | PASS |
| 174 | Unknown kind | 0 | NO | PASS |
| 175 | Unknown kind | 9 | NO | PASS |
| 176 | Unknown kind | NSIntegerMax | NO | PASS |
| 177 | Unknown kind | negative cast | NO | PASS |
| 178 | Construction and audit | options=0 accepts all canonical policies | Confirmed | PASS |
| 179 | Construction and audit | App Groups option does not hit code 106 | Confirmed | PASS |
| 180 | Construction and audit | Preferences option does not hit code 106 | Confirmed | PASS |
| 181 | Construction and audit | Keychain option passes canonical gate | Confirmed | PASS |
| 182 | Construction and audit | All options pass canonical gate | Confirmed | PASS |
| 183 | Construction and audit | Completed Keychain output reaches writer | Confirmed | PASS |
| 184 | Construction and audit | Partial usable Keychain output reaches writer | Confirmed | PASS |
| 185 | Construction and audit | Protection failure omits Keychain | Confirmed | PASS |
| 186 | Construction and audit | Protection failure adds one generic warning | Confirmed | PASS |
| 187 | Construction and audit | Protection failure continues backup | Confirmed | PASS |
| 188 | Construction and audit | Required data failure still aborts | Confirmed | PASS |
| 189 | Construction and audit | Invalid synthetic Keychain disposition rejects | Confirmed | PASS |
| 190 | Construction and audit | Invalid synthetic Keychain mode rejects | Confirmed | PASS |
| 191 | Construction and audit | Invalid synthetic Keychain protection rejects | Confirmed | PASS |
| 192 | Construction and audit | Final audit accepts canonical ApplicationData | Confirmed | PASS |
| 193 | Construction and audit | Final audit accepts canonical optional record | Confirmed | PASS |
| 194 | Construction and audit | Final audit accepts canonical Keychain | Confirmed | PASS |
| 195 | Construction and audit | Final audit rejects mutated Keychain protection | Confirmed | PASS |
| 196 | Construction and audit | Final audit rejects mutated Preferences mode | Confirmed | PASS |
| 197 | Construction and audit | Canonical array count remains eight | Confirmed | PASS |
| 198 | Warning and error | Protection warning exact text retained | Confirmed | PASS |
| 199 | Warning and error | Protection warning count remains one | Confirmed | PASS |
| 200 | Warning and error | No raw writer error appended | Confirmed | PASS |
| 201 | Warning and error | No duplicate warning added | Confirmed | PASS |
| 202 | Warning and error | No enum value in warning | Confirmed | PASS |
| 203 | Warning and error | Preferences silent omission retained | Confirmed | PASS |
| 204 | Warning and error | PXBackupErrorDomain retained | Confirmed | PASS |
| 205 | Warning and error | Code 106 retained | Confirmed | PASS |
| 206 | Warning and error | No new error code | Confirmed | PASS |
| 207 | Warning and error | Code 106 rejects real mutation | Confirmed | PASS |
| 208 | Warning and error | Code 106 does not reject canonical Keychain | Confirmed | PASS |
| 209 | Warning and error | Failure-policy function unchanged | Confirmed | PASS |
| 210 | Protected hash | AppDataBackupManager.h | Byte-identical | PASS |
| 211 | Protected hash | AppDataBackupRestoreViewController.h | Byte-identical | PASS |
| 212 | Protected hash | AppDataBackupRestoreViewController.m | Byte-identical | PASS |
| 213 | Protected hash | KeychainHelper/KeychainBackupHelper.h | Byte-identical | PASS |
| 214 | Protected hash | KeychainHelper/KeychainBackupHelper.m | Byte-identical | PASS |
| 215 | Protected hash | KeychainHelper/PXKeychainHelperExitCode.h | Byte-identical | PASS |
| 216 | Protected hash | KeychainHelper/PXKeychainHelperResult.h | Byte-identical | PASS |
| 217 | Protected hash | KeychainHelper/PXKeychainHelperResult.m | Byte-identical | PASS |
| 218 | Protected hash | KeychainHelper/PXKeychainItemIdentity.h | Byte-identical | PASS |
| 219 | Protected hash | KeychainHelper/PXKeychainItemIdentity.m | Byte-identical | PASS |
| 220 | Protected hash | KeychainHelper/backup_helper.m | Byte-identical | PASS |
| 221 | Protected hash | Makefile | Byte-identical | PASS |
| 222 | Protected hash | PXBackupArtifactPolicy.h | Byte-identical | PASS |
| 223 | Protected hash | PXBackupArtifactPolicy.m | Byte-identical | PASS |
| 224 | Protected hash | PXBackupArtifactVerifier.h | Byte-identical | PASS |
| 225 | Protected hash | PXBackupArtifactVerifier.m | Byte-identical | PASS |
| 226 | Protected hash | PXBackupArtifactWriter.h | Byte-identical | PASS |
| 227 | Protected hash | PXBackupArtifactWriter.m | Byte-identical | PASS |
| 228 | Protected hash | PXBackupDirectoryPublisher.h | Byte-identical | PASS |
| 229 | Protected hash | PXBackupDirectoryPublisher.m | Byte-identical | PASS |
| 230 | Protected hash | PXBackupManifestV4.h | Byte-identical | PASS |
| 231 | Protected hash | PXBackupManifestV4.m | Byte-identical | PASS |
| 232 | Protected hash | PXBackupManifestValidator.h | Byte-identical | PASS |
| 233 | Protected hash | PXBackupManifestValidator.m | Byte-identical | PASS |
| 234 | Protected hash | PXBackupPublicationWorkspace.h | Byte-identical | PASS |
| 235 | Protected hash | PXBackupPublicationWorkspace.m | Byte-identical | PASS |
| 236 | Protected hash | PXFileProtection.h | Byte-identical | PASS |
| 237 | Protected hash | PXFileProtection.m | Byte-identical | PASS |
| 238 | Protected hash | PXKeychainHelperInvocationResult.h | Byte-identical | PASS |
| 239 | Protected hash | PXKeychainHelperInvocationResult.m | Byte-identical | PASS |
| 240 | Protected hash | PXOptionalRestoreStaging.h | Byte-identical | PASS |
| 241 | Protected hash | PXOptionalRestoreStaging.m | Byte-identical | PASS |
| 242 | Protected hash | PXRestorePlan.h | Byte-identical | PASS |
| 243 | Protected hash | PXRestorePlan.m | Byte-identical | PASS |
| 244 | Protected hash | PXRestoreResult.h | Byte-identical | PASS |
| 245 | Protected hash | PXRestoreResult.m | Byte-identical | PASS |
| 246 | Protected hash | ProfileManagerViewController.m | Byte-identical | PASS |
| 247 | Protected hash | ProjectXViewController.m | Byte-identical | PASS |
| 248 | Protected hash | WeaponXKeychainBridge/Tweak.m | Byte-identical | PASS |
| 249 | Protected hash | docs/backup-restore-hardening/reports/TASK-4.9-REPORT.md | Byte-identical | PASS |
| 250 | Protected hash | scripts/keychain_backup.sh | Byte-identical | PASS |
| 251 | Scope and boundary | AppDataBackupRestoreViewController.h unchanged | Confirmed | PASS |
| 252 | Scope and boundary | AppDataBackupRestoreViewController.m unchanged | Confirmed | PASS |
| 253 | Scope and boundary | ProfileManagerViewController.m unchanged | Confirmed | PASS |
| 254 | Scope and boundary | ProjectXViewController.m unchanged | Confirmed | PASS |
| 255 | Scope and boundary | No Backup Successful title | Confirmed | PASS |
| 256 | Scope and boundary | No Backup Completed with Warnings title | Confirmed | PASS |
| 257 | Scope and boundary | No Backup Failed title classifier | Confirmed | PASS |
| 258 | Scope and boundary | Makefile unchanged | Confirmed | PASS |
| 259 | Scope and boundary | No test source in target | Confirmed | PASS |
| 260 | Scope and boundary | TASK-4.9 report unchanged | Confirmed | PASS |
| 261 | Scope and boundary | Artifact policy factory unchanged | Confirmed | PASS |
| 262 | Scope and boundary | Writer unchanged | Confirmed | PASS |
| 263 | Scope and boundary | Manifest builder unchanged | Confirmed | PASS |
| 264 | Scope and boundary | Manifest validator unchanged | Confirmed | PASS |
| 265 | Scope and boundary | Publisher unchanged | Confirmed | PASS |
| 266 | Scope and boundary | Artifact verifier unchanged | Confirmed | PASS |
| 267 | Scope and boundary | File-protection utility unchanged | Confirmed | PASS |
| 268 | Scope and boundary | Restore staging unchanged | Confirmed | PASS |
| 269 | Scope and boundary | Keychain helper unchanged | Confirmed | PASS |
| 270 | Scope and boundary | Wrapper unchanged | Confirmed | PASS |
| 271 | Scope and boundary | Bridge unchanged | Confirmed | PASS |
| 272 | Scope and boundary | TASK-5.1 not started | Confirmed | PASS |
| 273 | Scope and boundary | No implementation review | Confirmed | PASS |
| 274 | Scope and boundary | No coordinator closure update | Confirmed | PASS |
| 275 | Scope and boundary | No push | Confirmed | PASS |
| 276 | Deterministic fuzz partition | Partition 001 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 277 | Deterministic fuzz partition | Partition 002 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 278 | Deterministic fuzz partition | Partition 003 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 279 | Deterministic fuzz partition | Partition 004 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 280 | Deterministic fuzz partition | Partition 005 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 281 | Deterministic fuzz partition | Partition 006 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 282 | Deterministic fuzz partition | Partition 007 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 283 | Deterministic fuzz partition | Partition 008 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 284 | Deterministic fuzz partition | Partition 009 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 285 | Deterministic fuzz partition | Partition 010 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 286 | Deterministic fuzz partition | Partition 011 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 287 | Deterministic fuzz partition | Partition 012 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 288 | Deterministic fuzz partition | Partition 013 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 289 | Deterministic fuzz partition | Partition 014 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 290 | Deterministic fuzz partition | Partition 015 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 291 | Deterministic fuzz partition | Partition 016 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 292 | Deterministic fuzz partition | Partition 017 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 293 | Deterministic fuzz partition | Partition 018 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 294 | Deterministic fuzz partition | Partition 019 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 295 | Deterministic fuzz partition | Partition 020 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 296 | Deterministic fuzz partition | Partition 021 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 297 | Deterministic fuzz partition | Partition 022 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 298 | Deterministic fuzz partition | Partition 023 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 299 | Deterministic fuzz partition | Partition 024 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 300 | Deterministic fuzz partition | Partition 025 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 301 | Deterministic fuzz partition | Partition 026 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 302 | Deterministic fuzz partition | Partition 027 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 303 | Deterministic fuzz partition | Partition 028 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 304 | Deterministic fuzz partition | Partition 029 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 305 | Deterministic fuzz partition | Partition 030 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 306 | Deterministic fuzz partition | Partition 031 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 307 | Deterministic fuzz partition | Partition 032 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 308 | Deterministic fuzz partition | Partition 033 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 309 | Deterministic fuzz partition | Partition 034 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 310 | Deterministic fuzz partition | Partition 035 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 311 | Deterministic fuzz partition | Partition 036 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 312 | Deterministic fuzz partition | Partition 037 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 313 | Deterministic fuzz partition | Partition 038 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 314 | Deterministic fuzz partition | Partition 039 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 315 | Deterministic fuzz partition | Partition 040 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 316 | Deterministic fuzz partition | Partition 041 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 317 | Deterministic fuzz partition | Partition 042 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 318 | Deterministic fuzz partition | Partition 043 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 319 | Deterministic fuzz partition | Partition 044 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 320 | Deterministic fuzz partition | Partition 045 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 321 | Deterministic fuzz partition | Partition 046 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 322 | Deterministic fuzz partition | Partition 047 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 323 | Deterministic fuzz partition | Partition 048 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 324 | Deterministic fuzz partition | Partition 049 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 325 | Deterministic fuzz partition | Partition 050 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 326 | Deterministic fuzz partition | Partition 051 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 327 | Deterministic fuzz partition | Partition 052 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 328 | Deterministic fuzz partition | Partition 053 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 329 | Deterministic fuzz partition | Partition 054 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 330 | Deterministic fuzz partition | Partition 055 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 331 | Deterministic fuzz partition | Partition 056 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 332 | Deterministic fuzz partition | Partition 057 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 333 | Deterministic fuzz partition | Partition 058 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 334 | Deterministic fuzz partition | Partition 059 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 335 | Deterministic fuzz partition | Partition 060 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 336 | Deterministic fuzz partition | Partition 061 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 337 | Deterministic fuzz partition | Partition 062 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 338 | Deterministic fuzz partition | Partition 063 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 339 | Deterministic fuzz partition | Partition 064 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 340 | Deterministic fuzz partition | Partition 065 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 341 | Deterministic fuzz partition | Partition 066 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 342 | Deterministic fuzz partition | Partition 067 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 343 | Deterministic fuzz partition | Partition 068 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 344 | Deterministic fuzz partition | Partition 069 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 345 | Deterministic fuzz partition | Partition 070 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 346 | Deterministic fuzz partition | Partition 071 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 347 | Deterministic fuzz partition | Partition 072 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 348 | Deterministic fuzz partition | Partition 073 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 349 | Deterministic fuzz partition | Partition 074 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 350 | Deterministic fuzz partition | Partition 075 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 351 | Deterministic fuzz partition | Partition 076 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 352 | Deterministic fuzz partition | Partition 077 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 353 | Deterministic fuzz partition | Partition 078 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 354 | Deterministic fuzz partition | Partition 079 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 355 | Deterministic fuzz partition | Partition 080 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 356 | Deterministic fuzz partition | Partition 081 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 357 | Deterministic fuzz partition | Partition 082 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 358 | Deterministic fuzz partition | Partition 083 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 359 | Deterministic fuzz partition | Partition 084 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 360 | Deterministic fuzz partition | Partition 085 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 361 | Deterministic fuzz partition | Partition 086 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 362 | Deterministic fuzz partition | Partition 087 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 363 | Deterministic fuzz partition | Partition 088 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 364 | Deterministic fuzz partition | Partition 089 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 365 | Deterministic fuzz partition | Partition 090 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 366 | Deterministic fuzz partition | Partition 091 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 367 | Deterministic fuzz partition | Partition 092 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 368 | Deterministic fuzz partition | Partition 093 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 369 | Deterministic fuzz partition | Partition 094 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 370 | Deterministic fuzz partition | Partition 095 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 371 | Deterministic fuzz partition | Partition 096 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 372 | Deterministic fuzz partition | Partition 097 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 373 | Deterministic fuzz partition | Partition 098 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 374 | Deterministic fuzz partition | Partition 099 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 375 | Deterministic fuzz partition | Partition 100 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 376 | Deterministic fuzz partition | Partition 101 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 377 | Deterministic fuzz partition | Partition 102 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 378 | Deterministic fuzz partition | Partition 103 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 379 | Deterministic fuzz partition | Partition 104 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 380 | Deterministic fuzz partition | Partition 105 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 381 | Deterministic fuzz partition | Partition 106 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 382 | Deterministic fuzz partition | Partition 107 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 383 | Deterministic fuzz partition | Partition 108 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 384 | Deterministic fuzz partition | Partition 109 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 385 | Deterministic fuzz partition | Partition 110 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 386 | Deterministic fuzz partition | Partition 111 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 387 | Deterministic fuzz partition | Partition 112 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 388 | Deterministic fuzz partition | Partition 113 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 389 | Deterministic fuzz partition | Partition 114 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 390 | Deterministic fuzz partition | Partition 115 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 391 | Deterministic fuzz partition | Partition 116 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 392 | Deterministic fuzz partition | Partition 117 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 393 | Deterministic fuzz partition | Partition 118 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 394 | Deterministic fuzz partition | Partition 119 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 395 | Deterministic fuzz partition | Partition 120 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 396 | Deterministic fuzz partition | Partition 121 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 397 | Deterministic fuzz partition | Partition 122 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 398 | Deterministic fuzz partition | Partition 123 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 399 | Deterministic fuzz partition | Partition 124 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 400 | Deterministic fuzz partition | Partition 125 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 401 | Deterministic fuzz partition | Partition 126 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 402 | Deterministic fuzz partition | Partition 127 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 403 | Deterministic fuzz partition | Partition 128 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 404 | Deterministic fuzz partition | Partition 129 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 405 | Deterministic fuzz partition | Partition 130 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 406 | Deterministic fuzz partition | Partition 131 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 407 | Deterministic fuzz partition | Partition 132 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 408 | Deterministic fuzz partition | Partition 133 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 409 | Deterministic fuzz partition | Partition 134 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 410 | Deterministic fuzz partition | Partition 135 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 411 | Deterministic fuzz partition | Partition 136 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 412 | Deterministic fuzz partition | Partition 137 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 413 | Deterministic fuzz partition | Partition 138 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 414 | Deterministic fuzz partition | Partition 139 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 415 | Deterministic fuzz partition | Partition 140 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 416 | Deterministic fuzz partition | Partition 141 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 417 | Deterministic fuzz partition | Partition 142 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 418 | Deterministic fuzz partition | Partition 143 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 419 | Deterministic fuzz partition | Partition 144 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |
| 420 | Deterministic fuzz partition | Partition 145 of canonical-equivalence fuzz corpus | Exact matcher equivalence | PASS |

## Objective-C/toolchain status
The Windows host does not provide `clang.exe`, `make.exe`, `xcrun.exe`, or `THEOS`. Apple SDK compile, arm64/arm64e build, ProjectX link, package build, and GitHub Actions therefore remain PENDING and are not claimed as passed.

## Device test status
Device backup smoke tests are PENDING: data-only, App Groups, Preferences, Keychain, all-options, completed helper, partial usable helper, protection failure omission, required data failure, and invalid synthetic policy. Deterministic construction/audit models passed but do not replace device execution.

## Line-ending/NUL audit
| File | Encoding/endings | NUL | Final newline | New trailing whitespace |
|---|---|---|---|---|
| `AppDataBackupManager.m` | UTF-8 LF | none | present | none in added lines |
| `TASK-4.9A-REPORT.md` | UTF-8 LF | none | present | none |

No broad formatting or unrelated line-ending normalization was performed.

## Residual risks
Apple compilation and device smoke execution remain unavailable on this host. The deterministic model mirrors the explicit manager matrix but is not an Objective-C runtime test. Pre-existing coordinator-owned working-tree content remains outside this implementation commit.

## TASK-5.1 boundary
TASK-5.1 was not started. Backup/restore alert titles, component UI, advanced-scope confirmation, Phase 6 work, review creation, coordinator Phase-4 closure updates, and push are explicitly excluded.

GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
