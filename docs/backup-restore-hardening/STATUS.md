# Implementation Status

## Current Gate

```text
Program: Backup / Restore Hardening
Current phase: Phase 4 - Keychain Safety
Current task: TASK-4.4 - Define Exact Keychain Item Identity
Task file: docs/backup-restore-hardening/tasks/TASK-4.4-define-exact-keychain-item-identity.md
Expected report: docs/backup-restore-hardening/reports/TASK-4.4-REPORT.md
Status: READY
Baseline: 4c7000289186a4d7cb3772bc7c4b80b24ab4c3f1
Build owner: Project owner via GitHub Actions / Theos
Next task: TASK-4.5 remains LOCKED
```

## Completed phases

### Phase 0 - Reliable Command Execution

COMPLETED.

### Phase 1 - Safe Restore Destination and Destructive Boundaries

COMPLETED, including TASK-1.1 through TASK-1.12.

### Phase 2 - Fail-Closed Restore Planning, Staging and Transactions

COMPLETED, including TASK-2.1 through TASK-2.14 and corrective tasks TASK-2.6A, TASK-2.11A, TASK-2.13A and TASK-2.14A.

### Phase 3 - Atomic Backup Publication

COMPLETED, including all corrective tasks through TASK-3.10A.

## Phase 4 accepted foundation

### TASK-4.1 - Structured helper result

```text
1a59e96258651aa9c6aa8d77a1e6debea67ab524
phase4(task-4.1): add structured keychain helper result
```

Accepted:

```text
immutable bounded PXKeychainHelperResult
schemaVersion 1
exact ten-key property-list root
binary plist + base64 framing
one prefixed stdout line
no secret, identity, path or human diagnostic fields
```

### TASK-4.2 - Reliable helper exit codes

```text
5c6e70ac4ecd815727c50216c80176d1cf9f80f2
phase4(task-4.2): define reliable keychain helper exit codes
```

Accepted:

```text
direct codes: 0/10/20/21/30/40/50
wrapper-only codes: 60 through 65
one direct finalizer
Partial -> 10
protocol mismatch -> INVALID + 50
recognized child code pass-through
unknown child status -> 40
current callers remain zero/nonzero consumers
```

### TASK-4.3 - Remove broad restore pre-delete

Implementation commit:

```text
4c7000289186a4d7cb3772bc7c4b80b24ab4c3f1
phase4(task-4.3): remove broad keychain restore pre-delete
```

Review:

```text
docs/backup-restore-hardening/reviews/TASK-4.3-REVIEW.md
Production source review: ACCEPTED
TASK-4.3: COMPLETED
TASK-4.4 may open: YES
```

Accepted restore behavior:

```text
restore SecItemDelete: 0
restore SecItemUpdate: 0
restore SecItemAdd: 1
sole core SecItemDelete: explicit wipe only
overwrite request: no group/class delete authority
new item: add normally
duplicate with overwrite NO: preserve + warning + failed item
duplicate with overwrite YES: preserve + pending-safe-replacement warning + failed item
all-new overwrite restore: eligible for Completed / 0
any duplicate or add error: Partial / 10
```

TASK-4.3 keeps exact identity and per-item upsert locked for later tasks.

## Phase 4 current objective

TASK-4.4 creates an immutable, class-specific Keychain identity authority.

The factory input is an already-decoded Security item/add dictionary. It must derive an exact bounded match-query snapshot without executing the query.

Supported classes and required tuples:

```text
generic password:
  class + accessGroup + synchronizable + account + service

internet password:
  class + accessGroup + synchronizable + account + server + port
  + protocol + authenticationType + path + securityDomain

certificate:
  class + accessGroup + synchronizable + issuer + serialNumber

key:
  class + accessGroup + synchronizable + applicationLabel + keyClass + keyType

identity:
  class + accessGroup + synchronizable + applicationLabel + issuer + serialNumber
```

TASK-4.4 is foundation-only:

```text
no SecItemCopyMatching
no SecItemAdd
no SecItemUpdate
no SecItemDelete
no restore integration
no duplicate behavior change
no result/exit/wrapper change
```

TASK-4.5 alone may consume the accepted identity object for per-item upsert.

## Phase-4 task gate

```text
TASK-4.1 Add structured helper result: COMPLETED
TASK-4.2 Define reliable helper exit codes: COMPLETED
TASK-4.3 Remove broad pre-delete from restore: COMPLETED
TASK-4.4 Define exact identity for each Keychain class: READY
TASK-4.5 Implement per-item upsert: LOCKED
TASK-4.6 Secure helper temporary workspace and path validation: LOCKED
TASK-4.7 Report requested and effective access groups: LOCKED
TASK-4.8 Integrate partial Keychain result into manager: LOCKED
TASK-4.9 Finalize Keychain backup protection policy: LOCKED
Phase 5: LOCKED
Phase 6: LOCKED
```

## TASK-4.4 authorized scope

```text
A KeychainHelper/PXKeychainItemIdentity.h
A KeychainHelper/PXKeychainItemIdentity.m
M Makefile
A docs/backup-restore-hardening/reports/TASK-4.4-REPORT.md
```

## TASK-4.4 protected foundation

```text
KeychainHelper/KeychainBackupHelper.h/.m
KeychainHelper/PXKeychainHelperResult.h/.m
KeychainHelper/PXKeychainHelperExitCode.h
KeychainHelper/backup_helper.m
scripts/keychain_backup.sh
AppDataBackupManager.h/.m
AppDataCleaner.h/.m
WeaponXKeychainBridge/Tweak.m
Phase-1 through Phase-3 production source
Restore infrastructure
UI/controllers
```

## TASK-4.4 required boundaries

TASK-4.4 must:

```text
use exact runtime-type proof
create immutable deep-copied identity snapshots
canonicalize absent synchronizable to false
reject wildcard/ambiguous identity subsets
create exact class-specific matchQuery dictionaries
exclude values, return controls and authentication controls
keep error/description output privacy-safe
compile the new source into backup_helper
```

TASK-4.4 must not add:

```text
Security operation calls
restore item rejection or lookup
SecItemUpdate
per-item delete/add replacement
rollback
backup schema changes
workspace/path hardening
requested/effective group reporting
manager/bridge parsing
UI changes
```

## Workspace ownership

Coordinator-owned modified/untracked documentation must not be staged, reverted, deleted, reformatted or rewritten by an implementation agent.

## Current repository gate

```text
HEAD: 4c7000289186a4d7cb3772bc7c4b80b24ab4c3f1
Phase 0: COMPLETED
Phase 1: COMPLETED
Phase 2: COMPLETED
Phase 3: COMPLETED
TASK-4.1: COMPLETED
TASK-4.2: COMPLETED
TASK-4.3: COMPLETED
TASK-4.4: READY
TASK-4.5: LOCKED
Phase 5: LOCKED
Phase 6: LOCKED
```

## Stop condition

The implementation agent stops after TASK-4.4 source, report and implementation commit. TASK-4.5 and all later tasks remain locked until owner build confirmation and coordinator acceptance.
