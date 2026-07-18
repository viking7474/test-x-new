# TASK-6.5 REPORT — Add Transaction Fault-Injection Tests

## Result

READY_FOR_REVIEW on the Windows implementation host. Prelude, fault engine, 96 self-test definitions, 90 transaction case definitions, crash/recovery orchestration, workflow integration, static audit and protected-hash gates are complete locally. macOS Objective-C compile and executable results remain PENDING GitHub Actions and are not reported as PASS.

## User authority, correction and baseline

- Required baseline: `433b379a27aa45fd4aee385b47729f82f8ed28e4`.
- TASK-6.4 review-file absence is accepted by user authority.
- Specification Correction 1 changes only protected TASK-6.4 report scenarios from 1227 to 1222.
- TASK-6.4 report remains 105005 bytes, SHA-256 `7340799b8164dec5679ff8373182f06f2cc4cd816dde4a2da156f45321942924`.
- TASK-6.4 generator: 86/86 PASS; static self-tests: 49/49 PASS; repository audit: 1703/1703 PASS; production drift: 0.
- TASK-6.6 was not started.

## Working-tree preservation and exact authorized scope

Coordinator-owned STATUS, ROADMAP, DECISIONS and README files and all pre-existing untracked task/review documents were preserved without staging, reset, rewrite, deletion or normalization.

| Status | Path |
|---|---|
| A | `tests/backup-restore-hardening/PXTransactionFaultInjectionPrelude.h` |
| A | `tests/backup-restore-hardening/PXTransactionFaultHarness.m` |
| M | `.github/workflows/build-ios-arm.yml` |
| A | `docs/backup-restore-hardening/reports/TASK-6.5-REPORT.md` |

No production transaction, resolver, staging, destructive-validator, manager, restore-result, Makefile, static-audit, TASK-6.4 test, Keychain or backup-publication source was modified.

## Transaction scope and excluded surfaces

The test build compiles unchanged `PXMainDataRestoreTransaction.m`, `PXAppGroupRestoreTransaction.m`, and `PXOptionalRestoreTransaction.m`. Main and App Group link real unchanged `PXResolvedContainer.m`. No transaction logic is copied. Keychain Restore, backup publication/cleanup/writers/workspaces, manager/UI aggregation, device-only APFS semantics and Phase 3 publication races are excluded.

## Test-build architecture and production protection

Three independent macOS binaries are built: MAIN-tests, APP_GROUP-tests and OPTIONAL-tests. Each contains one unchanged production transaction object and one shared harness object compiled with exactly one domain macro. Only production compilation receives `-DPX_TRANSACTION_FAULT_INJECTION=1` and the forced prelude include; the harness calls real libc without redirects.

The harness supplies minimal immutable models only for `PXValidatedMainDataStage`, `PXValidatedOptionalFileStage`, `PXAppGroupRestoreTarget`, and the transaction-isolating test `PXDestructivePathValidator`. It never implements a transaction class, `PXOptionalRestoreTransactionItem`, or `PXResolvedContainer`. There are no production conditionals, swizzles, source patches, copied transaction functions, DYLD insertion, fishhook or private runtime APIs.

## Prelude, variadic forwarding and wrappers

The prelude imports all system declarations before redirects and contains exactly 20 declarations and 20 redirects: open, openat, close, dup, fcntl, flock, fstat, fstatat, lstat, fchmod, lseek, mkdirat, renameat, unlinkat, fsync, write, read, fdopendir, readdir and closedir. It does not redirect `_exit`, kill, waitpid, posix_spawn, allocation, Foundation filesystem APIs or CommonCrypto.

Open/openat consume `mode_t` only with `O_CREAT`. Fcntl handles `F_GETFD` without an argument and `F_SETFD`, `F_DUPFD`, and Darwin `F_DUPFD_CLOEXEC` with an integer. Unknown commands fail deterministically rather than reading an unknown variadic argument.

## Fault actions, roles and semantic events

Rules contain primitive, semantic event, occurrence, action, errno, bounded EINTR budget and optional synthetic `st_dev`. Actions are pass, fail-before, fail-after-close, EINTR-then-success, mutate-successful-fstat-device, crash-before and crash-after-success. Two ordered rules encode operation failure followed by rollback-specific failure.

Roles include target, target-lock, stage, authority, workspace, participant/leader workspace, original, new, replacement and journal temporary/final. They propagate through open/openat/dup/fdopendir and are removed on close/closedir. Events cover workspace creation/sync, journal temp open/write/fsync/close, publication rename/directory fsync, transaction moves, replacement I/O and cleanup.

Fail-before does not call libc. Fail-after-close performs one real close and removes tracking before reporting errno. EINTR is finite. Device mutation changes only a successful returned `struct stat`. Crash actions use `kill(getpid(), SIGKILL)`.

## Journal phases, child protocol and stale recovery

Durable phases are numbered prepared=1, quarantined=2, installed=3, committed=4, rolling-back=5 and rolled-back=6. Durability requires successful journal rename followed by publication-directory fsync.

For every crash case the parent creates the fixture, spawns its own executable, requires SIGKILL, inspects durable residue, then starts a fresh recovery process. Recovery reconstructs models and invokes the production factory; no private recovery helper is called directly.

## Fixture, snapshot, state and privacy models

Each case uses a fresh temporary root mode 0700, directories 0700 and files 0600, one filesystem, fixed contents and fixed UUIDs, with no links or special files. Snapshots classify ORIGINAL, INSTALLED, MIXED, ROLLBACK_EVIDENCE or COMMITTED_CLEANUP_WARNING and reject false completion. Privacy separately rejects roots, destinations, stages, UUIDs, contents, journal bytes, descriptor values and rule ordinals.

Main uses two original and two staged files. App Group uses two targets and stages in deliberately unsorted caller order. Optional distinguishes DirectoryContents, DirectoryObject and FileObject, uses all three in one durable decision, and excludes Keychain from rollback.

## Optional independent tree digest and fixed vectors

The helper independently hashes `PXMainDataStageTreeV1\0`, D/F type, big-endian path length, UTF-8 relative path, big-endian mode and size, and file bytes in bytewise name order. It calculates entry/file/directory/byte totals and does not call private production hash helpers.

| Vector | SHA-256 |
|---|---|
| Empty | `4781eb8ee86207d7309c365562cd9d60abba337c3a9957770fa1f57b18d55c17` |
| One file | `218d4a891457dc2cfb0f41ba8e1a119346b214722d0b6e20ad81f289924d1b92` |
| Directory and file | `c6b0d673ade04c481ab6ef3d48e02c3541890089e7e4dce67d739ebf74234ed0` |
| Ordered siblings | `03574541e489c2316a58e35574b7cd872953402f0ab9a48592b191ada312e8b7` |

## CLI, self-tests and deterministic output

Public modes are exactly `--self-test` and `--run-all`; internal `--child` and `--recover` are parent-only. Unknown input exits 2. Failure output is sorted by case, assertion and message. Every domain runs exactly 32 common self-tests before any transaction case.

Expected macOS output, not yet observed:

```text
transaction fault self-test [main]: PASS (32/32)
transaction fault cases [main]: PASS (30/30)
transaction fault self-test [app-group]: PASS (32/32)
transaction fault cases [app-group]: PASS (30/30)
transaction fault self-test [optional]: PASS (32/32)
transaction fault cases [optional]: PASS (30/30)
```

## Main 30-case table

| ID | Injection/control | Expected result/state | Exact error | Filesystem | Actual |
|---|---|---|---|---|---|
| M001 | clean commit | commit YES; error nil; cleanupWarning nil; committed=YES; rollbackPerformed=NO; rollbackComplete=NO; recovered=0 | none | INSTALLED; workspace absent | PENDING GitHub Actions |
| M002 | second commit on same object | second commit NO; committed remains YES; rollbackPerformed=NO | `PXMainDataRestoreTransactionErrorDomain` / InvalidInput(1) / `$.transaction` | INSTALLED unchanged | PENDING GitHub Actions |
| M003 | real competing flock on target | factory nil; no transaction object | `PXMainDataRestoreTransactionErrorDomain` / FilesystemInspectionFailed(3) / `$.destination` | ORIGINAL; no workspace | PENDING GitHub Actions |
| M004 | mutate stage st_dev | factory nil; no transaction object | `PXMainDataRestoreTransactionErrorDomain` / CrossDeviceBoundary(4) / `$.stage` | ORIGINAL; no workspace | PENDING GitHub Actions |
| M005 | one EINTR on prepared journal write | commit YES; error nil; cleanupWarning nil; committed=YES; rollbackPerformed=NO; rollbackComplete=NO; recovered=0 | none | INSTALLED; workspace absent | PENDING GitHub Actions |
| M006 | prepared journal temporary open fails ENOSPC | commit NO; committed=NO; rollbackPerformed=NO; rollbackComplete=NO | `PXMainDataRestoreTransactionErrorDomain` / JournalCreationFailed(6) / `$.journal` | ORIGINAL; workspace absent | PENDING GitHub Actions |
| M007 | prepared journal write fails ENOSPC | commit NO; committed=NO; rollbackPerformed=NO; rollbackComplete=NO | `PXMainDataRestoreTransactionErrorDomain` / JournalCreationFailed(6) / `$.journal` | ORIGINAL; workspace absent | PENDING GitHub Actions |
| M008 | prepared journal temporary-file fsync fails EIO | commit NO; committed=NO; rollbackPerformed=NO; rollbackComplete=NO | `PXMainDataRestoreTransactionErrorDomain` / JournalCreationFailed(6) / `$.journal` | ORIGINAL; workspace absent | PENDING GitHub Actions |
| M009 | prepared journal close reports EIO after real close | commit NO; committed=NO; rollbackPerformed=NO; rollbackComplete=NO | `PXMainDataRestoreTransactionErrorDomain` / JournalCreationFailed(6) / `$.journal` | ORIGINAL; workspace absent | PENDING GitHub Actions |
| M010 | prepared journal publication rename fails EIO | commit NO; committed=NO; rollbackPerformed=NO; rollbackComplete=NO | `PXMainDataRestoreTransactionErrorDomain` / JournalCreationFailed(6) / `$.journal` | ORIGINAL; workspace absent | PENDING GitHub Actions |
| M011 | first target-to-original rename fails | commit NO; committed=NO; rollbackPerformed=YES; rollbackComplete=YES | `PXMainDataRestoreTransactionErrorDomain` / QuarantineFailed(8) / `$.transaction.quarantine` | ORIGINAL; no mixed state; workspace cleaned | PENDING GitHub Actions |
| M012 | quarantine directory sync fails | commit NO; committed=NO; rollbackPerformed=YES; rollbackComplete=YES | `PXMainDataRestoreTransactionErrorDomain` / QuarantineFailed(8) / `$.transaction.quarantine` | ORIGINAL; no mixed state; workspace cleaned | PENDING GitHub Actions |
| M013 | quarantined journal publication fails | commit NO; committed=NO; rollbackPerformed=YES; rollbackComplete=YES | `PXMainDataRestoreTransactionErrorDomain` / JournalCreationFailed(6) / `$.journal` | ORIGINAL; rollback cleanup complete | PENDING GitHub Actions |
| M014 | first stage-to-target rename fails | commit NO; committed=NO; rollbackPerformed=YES; rollbackComplete=YES | `PXMainDataRestoreTransactionErrorDomain` / CommitFailed(9) / `$.transaction.commit` | ORIGINAL; no mixed state; workspace cleaned | PENDING GitHub Actions |
| M015 | install target/stage sync fails | commit NO; committed=NO; rollbackPerformed=YES; rollbackComplete=YES | `PXMainDataRestoreTransactionErrorDomain` / CommitFailed(9) / `$.transaction.commit` | ORIGINAL; no mixed state; workspace cleaned | PENDING GitHub Actions |
| M016 | installed journal publication fails | commit NO; committed=NO; rollbackPerformed=YES; rollbackComplete=YES | `PXMainDataRestoreTransactionErrorDomain` / JournalCreationFailed(6) / `$.journal` | ORIGINAL; rollback cleanup complete | PENDING GitHub Actions |
| M017 | final test validator rejects target | commit NO; committed=NO; rollbackPerformed=YES; rollbackComplete=YES | `PXMainDataRestoreTransactionErrorDomain` / FilesystemChanged(12) / `$.transaction.commit` | ORIGINAL; no mixed state; workspace cleaned | PENDING GitHub Actions |
| M018 | committed journal publication fails | commit NO; committed=NO; rollbackPerformed=YES; rollbackComplete=YES | `PXMainDataRestoreTransactionErrorDomain` / JournalCreationFailed(6) / `$.journal` | ORIGINAL; rollback cleanup complete | PENDING GitHub Actions |
| M019 | rollback target-to-new rename fails | commit NO; committed=NO; rollbackPerformed=YES; rollbackComplete=NO | `PXMainDataRestoreTransactionErrorDomain` / RollbackFailed(10) / `$.transaction.rollback.new` | ROLLBACK_EVIDENCE retained; no false completion | PENDING GitHub Actions |
| M020 | rollback original-to-target rename fails | commit NO; committed=NO; rollbackPerformed=YES; rollbackComplete=NO | `PXMainDataRestoreTransactionErrorDomain` / RollbackFailed(10) / `$.transaction.rollback.original` | ROLLBACK_EVIDENCE retained; no false completion | PENDING GitHub Actions |
| M021 | rolled-back journal publication fails | commit NO; committed=NO; rollbackPerformed=YES; rollbackComplete=NO | `PXMainDataRestoreTransactionErrorDomain` / RollbackFailed(10) / `$.transaction.rollback` | ROLLBACK_EVIDENCE retained; no false completion | PENDING GitHub Actions |
| M022 | cleanup unlink fails after committed decision | commit YES; error nil; cleanupWarning nonnil; committed=YES; rollbackPerformed=NO | `PXMainDataRestoreTransactionErrorDomain` / CleanupFailed(11) / `$.transaction.cleanup` | COMMITTED_CLEANUP_WARNING; installed data intact | PENDING GitHub Actions |
| M023 | crash after durable prepared phase | child SIGKILL; fresh production-factory recovery succeeds; recoveredStaleTransactionCount=1 | none | ORIGINAL restored; workspace cleaned | PENDING GitHub Actions |
| M024 | crash after first quarantine rename before phase publication | child SIGKILL; fresh production-factory recovery succeeds; recoveredStaleTransactionCount=1 | none | ORIGINAL restored; workspace cleaned | PENDING GitHub Actions |
| M025 | crash after durable quarantined phase | child SIGKILL; fresh production-factory recovery succeeds; recoveredStaleTransactionCount=1 | none | ORIGINAL restored; workspace cleaned | PENDING GitHub Actions |
| M026 | crash after first install rename before installed publication | child SIGKILL; fresh production-factory recovery succeeds; recoveredStaleTransactionCount=1 | none | ORIGINAL restored; workspace cleaned | PENDING GitHub Actions |
| M027 | crash after durable installed phase | child SIGKILL; fresh production-factory recovery succeeds; recoveredStaleTransactionCount=1 | none | ORIGINAL restored; workspace cleaned | PENDING GitHub Actions |
| M028 | crash after durable committed phase | child SIGKILL; fresh production-factory recovery succeeds; recoveredStaleTransactionCount=1 | none | INSTALLED preserved; workspace cleaned | PENDING GitHub Actions |
| M029 | crash after durable rolling-back phase | child SIGKILL; fresh production-factory recovery succeeds; recoveredStaleTransactionCount=1 | none | ORIGINAL restored; workspace cleaned | PENDING GitHub Actions |
| M030 | crash after durable rolled-back phase | child SIGKILL; fresh production-factory recovery succeeds; recoveredStaleTransactionCount=1 | none | ORIGINAL restored; workspace cleaned | PENDING GitHub Actions |

## App Group 30-case table

| ID | Injection/control | Expected result/state | Exact error | Filesystem | Actual |
|---|---|---|---|---|---|
| G001 | clean two-target batch commit | commit YES; error nil; cleanupWarning nil; committed=YES; rollbackPerformed=NO; rollbackComplete=NO; targetCount=2; recovered=0 | none | both targets INSTALLED; no mixed target; no workspace | PENDING GitHub Actions |
| G002 | second commit | second commit NO; committed remains YES | `PXAppGroupRestoreTransactionErrorDomain` / InvalidInput(1) / `$` | both targets INSTALLED unchanged | PENDING GitHub Actions |
| G003 | real lock contention on first target | factory nil; no transaction object | `PXAppGroupRestoreTransactionErrorDomain` / LockFailed(4) / `$.locks` | both targets ORIGINAL; locks released | PENDING GitHub Actions |
| G004 | real lock contention on second target | factory nil; no transaction object | `PXAppGroupRestoreTransactionErrorDomain` / LockFailed(4) / `$.locks` | both targets ORIGINAL; locks released | PENDING GitHub Actions |
| G005 | mutate second stage st_dev | factory nil; no transaction object | `PXAppGroupRestoreTransactionErrorDomain` / CrossDeviceBoundary(5) / `$.stage` | both targets ORIGINAL | PENDING GitHub Actions |
| G006 | one EINTR on leader prepared-journal write | commit YES; error nil; cleanupWarning nil; committed=YES; rollbackPerformed=NO; rollbackComplete=NO; targetCount=2; recovered=0 | none | both targets INSTALLED; no mixed target; no workspace | PENDING GitHub Actions |
| G007 | second participant workspace mkdirat fails ENOSPC | commit NO; committed=NO; rollbackPerformed=NO; rollbackComplete=NO | `PXAppGroupRestoreTransactionErrorDomain` / JournalCreationFailed(7) / `$.journal` | both targets ORIGINAL; temporary workspaces cleaned | PENDING GitHub Actions |
| G008 | workspace/target preparation sync fails | commit NO; committed=NO; rollbackPerformed=NO; rollbackComplete=NO | `PXAppGroupRestoreTransactionErrorDomain` / JournalCreationFailed(7) / `$.journal` | both targets ORIGINAL; temporary workspaces cleaned | PENDING GitHub Actions |
| G009 | prepared leader-journal write fails ENOSPC | commit NO; committed=NO; rollbackPerformed=NO; rollbackComplete=NO | `PXAppGroupRestoreTransactionErrorDomain` / JournalCreationFailed(7) / `$.journal` | both targets ORIGINAL; temporary workspaces cleaned | PENDING GitHub Actions |
| G010 | prepared leader-journal publication fails | commit NO; committed=NO; rollbackPerformed=NO; rollbackComplete=NO | `PXAppGroupRestoreTransactionErrorDomain` / JournalCreationFailed(7) / `$.journal` | both targets ORIGINAL; temporary workspaces cleaned | PENDING GitHub Actions |
| G011 | first target quarantine rename fails | commit NO; committed=NO; rollbackPerformed=YES; rollbackComplete=YES | `PXAppGroupRestoreTransactionErrorDomain` / QuarantineFailed(9) / `$.transaction.quarantine` | whole batch ORIGINAL; no mixed target; workspace cleaned | PENDING GitHub Actions |
| G012 | second target quarantine rename fails | commit NO; committed=NO; rollbackPerformed=YES; rollbackComplete=YES | `PXAppGroupRestoreTransactionErrorDomain` / QuarantineFailed(9) / `$.transaction.quarantine` | whole batch ORIGINAL; no mixed target; workspace cleaned | PENDING GitHub Actions |
| G013 | quarantine sync fails | commit NO; committed=NO; rollbackPerformed=YES; rollbackComplete=YES | `PXAppGroupRestoreTransactionErrorDomain` / QuarantineFailed(9) / `$.transaction.quarantine` | whole batch ORIGINAL; no mixed target; workspace cleaned | PENDING GitHub Actions |
| G014 | quarantined leader-journal publication fails | commit NO; committed=NO; rollbackPerformed=YES; rollbackComplete=YES | `PXAppGroupRestoreTransactionErrorDomain` / QuarantineFailed(9) / `$.transaction.quarantine` | whole batch ORIGINAL; no mixed target; workspace cleaned | PENDING GitHub Actions |
| G015 | first target install rename fails | commit NO; committed=NO; rollbackPerformed=YES; rollbackComplete=YES | `PXAppGroupRestoreTransactionErrorDomain` / CommitFailed(10) / `$.transaction.commit` | whole batch ORIGINAL; no mixed target; workspace cleaned | PENDING GitHub Actions |
| G016 | second target install rename fails | commit NO; committed=NO; rollbackPerformed=YES; rollbackComplete=YES | `PXAppGroupRestoreTransactionErrorDomain` / CommitFailed(10) / `$.transaction.commit` | whole batch ORIGINAL; no mixed target; workspace cleaned | PENDING GitHub Actions |
| G017 | install sync fails | commit NO; committed=NO; rollbackPerformed=YES; rollbackComplete=YES | `PXAppGroupRestoreTransactionErrorDomain` / CommitFailed(10) / `$.transaction.commit` | whole batch ORIGINAL; no mixed target; workspace cleaned | PENDING GitHub Actions |
| G018 | installed leader-journal publication fails | commit NO; committed=NO; rollbackPerformed=YES; rollbackComplete=YES | `PXAppGroupRestoreTransactionErrorDomain` / CommitFailed(10) / `$.transaction.commit` | whole batch ORIGINAL; no mixed target; workspace cleaned | PENDING GitHub Actions |
| G019 | committed leader-journal publication fails | commit NO; committed=NO; rollbackPerformed=YES; rollbackComplete=YES | `PXAppGroupRestoreTransactionErrorDomain` / CommitFailed(10) / `$.transaction.commit` | whole batch ORIGINAL; no mixed target; workspace cleaned | PENDING GitHub Actions |
| G020 | rollback installed-to-new rename fails | commit NO; committed=NO; rollbackPerformed=YES; rollbackComplete=NO | `PXAppGroupRestoreTransactionErrorDomain` / RollbackFailed(11) / `$.transaction.rollback` | ROLLBACK_EVIDENCE retained; batch not falsely committed | PENDING GitHub Actions |
| G021 | rollback original restore fails | commit NO; committed=NO; rollbackPerformed=YES; rollbackComplete=NO | `PXAppGroupRestoreTransactionErrorDomain` / RollbackFailed(11) / `$.transaction.rollback` | ROLLBACK_EVIDENCE retained; batch not falsely committed | PENDING GitHub Actions |
| G022 | rolled-back leader-journal publication fails | commit NO; committed=NO; rollbackPerformed=YES; rollbackComplete=NO | `PXAppGroupRestoreTransactionErrorDomain` / RollbackFailed(11) / `$.transaction.rollback` | ROLLBACK_EVIDENCE retained; batch not falsely committed | PENDING GitHub Actions |
| G023 | nonleader cleanup unlink fails after commit | commit YES; error nil; cleanupWarning nonnil; committed=YES; rollbackPerformed=NO | `PXAppGroupRestoreTransactionErrorDomain` / CleanupFailed(12) / `$.transaction.cleanup` | both targets INSTALLED; confined evidence retained | PENDING GitHub Actions |
| G024 | leader cleanup fails after commit | commit YES; error nil; cleanupWarning nonnil; committed=YES; rollbackPerformed=NO | `PXAppGroupRestoreTransactionErrorDomain` / CleanupFailed(12) / `$.transaction.cleanup` | both targets INSTALLED; confined evidence retained | PENDING GitHub Actions |
| G025 | crash after durable prepared phase | child SIGKILL; fresh production-factory recovery succeeds; recoveredStaleBatchCount=1; targetCount=2 | none | both targets ORIGINAL; no mixed target; workspaces cleaned | PENDING GitHub Actions |
| G026 | crash after partial quarantine of later target | child SIGKILL; fresh production-factory recovery succeeds; recoveredStaleBatchCount=1; targetCount=2 | none | both targets ORIGINAL; no mixed target; workspaces cleaned | PENDING GitHub Actions |
| G027 | crash after durable quarantined phase | child SIGKILL; fresh production-factory recovery succeeds; recoveredStaleBatchCount=1; targetCount=2 | none | both targets ORIGINAL; no mixed target; workspaces cleaned | PENDING GitHub Actions |
| G028 | crash after partial install of later target | child SIGKILL; fresh production-factory recovery succeeds; recoveredStaleBatchCount=1; targetCount=2 | none | both targets ORIGINAL; no mixed target; workspaces cleaned | PENDING GitHub Actions |
| G029 | crash after durable installed phase | child SIGKILL; fresh production-factory recovery succeeds; recoveredStaleBatchCount=1; targetCount=2 | none | both targets ORIGINAL; no mixed target; workspaces cleaned | PENDING GitHub Actions |
| G030 | crash after durable committed phase | child SIGKILL; fresh production-factory recovery succeeds; recoveredStaleBatchCount=1; targetCount=2 | none | both targets INSTALLED; no mixed target; workspaces cleaned | PENDING GitHub Actions |

## Optional 30-case table

| ID | Injection/control | Expected result/state | Exact error | Filesystem | Actual |
|---|---|---|---|---|---|
| O001 | clean batch with all three item kinds | commit YES; error nil; cleanupWarning nil; committed=YES; rollbackPerformed=NO; rollbackComplete=NO; itemCount=3; recovered=0 | none | all three replacements INSTALLED; workspace absent | PENDING GitHub Actions |
| O002 | second commit | second commit NO; committed remains YES | `PXOptionalRestoreTransactionErrorDomain` / InvalidInput(1) / `$` | all installed replacements unchanged | PENDING GitHub Actions |
| O003 | DirectoryContents-only clean commit | commit YES; error nil; cleanupWarning nil; committed=YES; rollbackPerformed=NO; rollbackComplete=NO; itemCount=1; recovered=0 | none | selected replacement INSTALLED; workspace absent | PENDING GitHub Actions |
| O004 | DirectoryObject-only clean commit | commit YES; error nil; cleanupWarning nil; committed=YES; rollbackPerformed=NO; rollbackComplete=NO; itemCount=1; recovered=0 | none | selected replacement INSTALLED; workspace absent | PENDING GitHub Actions |
| O005 | FileObject-only clean commit | commit YES; error nil; cleanupWarning nil; committed=YES; rollbackPerformed=NO; rollbackComplete=NO; itemCount=1; recovered=0 | none | selected replacement INSTALLED; workspace absent | PENDING GitHub Actions |
| O006 | real authority lock contention | factory nil; no transaction object | `PXOptionalRestoreTransactionErrorDomain` / LockFailed(4) / `$.locks` | all optional originals intact | PENDING GitHub Actions |
| O007 | mutate file-stage st_dev | factory nil; no transaction object | `PXOptionalRestoreTransactionErrorDomain` / CrossDeviceBoundary(5) / `$.stage` | all optional originals intact | PENDING GitHub Actions |
| O008 | one EINTR on staged-file read | commit YES; error nil; cleanupWarning nil; committed=YES; rollbackPerformed=NO; rollbackComplete=NO; itemCount=3; recovered=0 | none | all three replacements INSTALLED; workspace absent | PENDING GitHub Actions |
| O009 | workspace creation mkdirat fails ENOSPC | commit NO; committed=NO; rollbackPerformed=NO; rollbackComplete=NO | `PXOptionalRestoreTransactionErrorDomain` / WorkspaceCreationFailed(7) / `$.workspace` | all originals intact; unprepared evidence cleaned | PENDING GitHub Actions |
| O010 | file replacement open fails EMFILE | commit NO; committed=NO; rollbackPerformed=NO; rollbackComplete=NO | `PXOptionalRestoreTransactionErrorDomain` / ReplacementPreparationFailed(8) / `$.replacement` | all originals intact; unprepared evidence cleaned | PENDING GitHub Actions |
| O011 | staged-file read fails EIO | commit NO; committed=NO; rollbackPerformed=NO; rollbackComplete=NO | `PXOptionalRestoreTransactionErrorDomain` / ReplacementMismatch(9) / `$.replacement` | all originals intact; unprepared evidence cleaned | PENDING GitHub Actions |
| O012 | replacement write fails ENOSPC | commit NO; committed=NO; rollbackPerformed=NO; rollbackComplete=NO | `PXOptionalRestoreTransactionErrorDomain` / ReplacementMismatch(9) / `$.replacement` | all originals intact; unprepared evidence cleaned | PENDING GitHub Actions |
| O013 | replacement-file fsync fails EIO | commit NO; committed=NO; rollbackPerformed=NO; rollbackComplete=NO | `PXOptionalRestoreTransactionErrorDomain` / ReplacementMismatch(9) / `$.replacement` | all originals intact; unprepared evidence cleaned | PENDING GitHub Actions |
| O014 | prepared leader-journal write fails | commit NO; committed=NO; rollbackPerformed=YES; rollbackComplete=YES | `PXOptionalRestoreTransactionErrorDomain` / JournalCreationFailed(10) / `$.journal` | all three originals restored; Keychain excluded; workspace cleaned | PENDING GitHub Actions |
| O015 | DirectoryContents quarantine rename fails | commit NO; committed=NO; rollbackPerformed=YES; rollbackComplete=YES | `PXOptionalRestoreTransactionErrorDomain` / QuarantineFailed(12) / `$.transaction.quarantine` | all three originals restored; Keychain excluded; workspace cleaned | PENDING GitHub Actions |
| O016 | DirectoryObject quarantine rename fails | commit NO; committed=NO; rollbackPerformed=YES; rollbackComplete=YES | `PXOptionalRestoreTransactionErrorDomain` / QuarantineFailed(12) / `$.transaction.quarantine` | all three originals restored; Keychain excluded; workspace cleaned | PENDING GitHub Actions |
| O017 | FileObject quarantine rename fails | commit NO; committed=NO; rollbackPerformed=YES; rollbackComplete=YES | `PXOptionalRestoreTransactionErrorDomain` / QuarantineFailed(12) / `$.transaction.quarantine` | all three originals restored; Keychain excluded; workspace cleaned | PENDING GitHub Actions |
| O018 | quarantined journal publication fails | commit NO; committed=NO; rollbackPerformed=YES; rollbackComplete=YES | `PXOptionalRestoreTransactionErrorDomain` / JournalCreationFailed(10) / `$.journal` | all three originals restored; Keychain excluded; workspace cleaned | PENDING GitHub Actions |
| O019 | DirectoryContents install rename fails | commit NO; committed=NO; rollbackPerformed=YES; rollbackComplete=YES | `PXOptionalRestoreTransactionErrorDomain` / CommitFailed(13) / `$.transaction.commit` | all three originals restored; Keychain excluded; workspace cleaned | PENDING GitHub Actions |
| O020 | DirectoryObject install rename fails | commit NO; committed=NO; rollbackPerformed=YES; rollbackComplete=YES | `PXOptionalRestoreTransactionErrorDomain` / CommitFailed(13) / `$.transaction.commit` | all three originals restored; Keychain excluded; workspace cleaned | PENDING GitHub Actions |
| O021 | FileObject install rename fails | commit NO; committed=NO; rollbackPerformed=YES; rollbackComplete=YES | `PXOptionalRestoreTransactionErrorDomain` / CommitFailed(13) / `$.transaction.commit` | all three originals restored; Keychain excluded; workspace cleaned | PENDING GitHub Actions |
| O022 | installed journal publication fails | commit NO; committed=NO; rollbackPerformed=YES; rollbackComplete=YES | `PXOptionalRestoreTransactionErrorDomain` / JournalCreationFailed(10) / `$.journal` | all three originals restored; Keychain excluded; workspace cleaned | PENDING GitHub Actions |
| O023 | committed journal publication fails | commit NO; committed=NO; rollbackPerformed=YES; rollbackComplete=YES | `PXOptionalRestoreTransactionErrorDomain` / JournalCreationFailed(10) / `$.journal` | all three originals restored; Keychain excluded; workspace cleaned | PENDING GitHub Actions |
| O024 | rollback installed replacement-to-new rename fails | commit NO; committed=NO; rollbackPerformed=YES; rollbackComplete=NO | `PXOptionalRestoreTransactionErrorDomain` / RollbackFailed(14) / `$.transaction.rollback.new` | ROLLBACK_EVIDENCE retained; no false completion | PENDING GitHub Actions |
| O025 | rollback original-object restore fails | commit NO; committed=NO; rollbackPerformed=YES; rollbackComplete=NO | `PXOptionalRestoreTransactionErrorDomain` / RollbackFailed(14) / `$.transaction.rollback.original` | ROLLBACK_EVIDENCE retained; no false completion | PENDING GitHub Actions |
| O026 | cleanup unlink fails after committed decision | commit YES; error nil; cleanupWarning nonnil; committed=YES; rollbackPerformed=NO | `PXOptionalRestoreTransactionErrorDomain` / CleanupFailed(15) / `$.transaction.cleanup` | all replacements INSTALLED; confined evidence retained | PENDING GitHub Actions |
| O027 | crash after durable prepared phase | child SIGKILL; fresh production-factory recovery succeeds; recoveredStaleTransactionCount=1; itemCount=3 | none | all optional originals restored; workspace cleaned; Keychain excluded | PENDING GitHub Actions |
| O028 | crash after partial quarantine | child SIGKILL; fresh production-factory recovery succeeds; recoveredStaleTransactionCount=1; itemCount=3 | none | all optional originals restored; workspace cleaned; Keychain excluded | PENDING GitHub Actions |
| O029 | crash after durable installed phase | child SIGKILL; fresh production-factory recovery succeeds; recoveredStaleTransactionCount=1; itemCount=3 | none | all optional originals restored; workspace cleaned; Keychain excluded | PENDING GitHub Actions |
| O030 | crash after durable committed phase | child SIGKILL; fresh production-factory recovery succeeds; recoveredStaleTransactionCount=1; itemCount=3 | none | all replacements INSTALLED; workspace cleaned; Keychain excluded | PENDING GitHub Actions |

## Exact per-case error domain, code and field

| ID | Domain | Code/name | Field-key constant | Exact field | Runtime |
|---|---|---|---|---|---|
| M001 | none expected | — | — | — | PENDING |
| M002 | `PXMainDataRestoreTransactionErrorDomain` | 1 / InvalidInput | `PXMainDataRestoreTransactionErrorFieldPathKey` | `$.transaction` | PENDING |
| M003 | `PXMainDataRestoreTransactionErrorDomain` | 3 / FilesystemInspectionFailed | `PXMainDataRestoreTransactionErrorFieldPathKey` | `$.destination` | PENDING |
| M004 | `PXMainDataRestoreTransactionErrorDomain` | 4 / CrossDeviceBoundary | `PXMainDataRestoreTransactionErrorFieldPathKey` | `$.stage` | PENDING |
| M005 | none expected | — | — | — | PENDING |
| M006 | `PXMainDataRestoreTransactionErrorDomain` | 6 / JournalCreationFailed | `PXMainDataRestoreTransactionErrorFieldPathKey` | `$.journal` | PENDING |
| M007 | `PXMainDataRestoreTransactionErrorDomain` | 6 / JournalCreationFailed | `PXMainDataRestoreTransactionErrorFieldPathKey` | `$.journal` | PENDING |
| M008 | `PXMainDataRestoreTransactionErrorDomain` | 6 / JournalCreationFailed | `PXMainDataRestoreTransactionErrorFieldPathKey` | `$.journal` | PENDING |
| M009 | `PXMainDataRestoreTransactionErrorDomain` | 6 / JournalCreationFailed | `PXMainDataRestoreTransactionErrorFieldPathKey` | `$.journal` | PENDING |
| M010 | `PXMainDataRestoreTransactionErrorDomain` | 6 / JournalCreationFailed | `PXMainDataRestoreTransactionErrorFieldPathKey` | `$.journal` | PENDING |
| M011 | `PXMainDataRestoreTransactionErrorDomain` | 8 / QuarantineFailed | `PXMainDataRestoreTransactionErrorFieldPathKey` | `$.transaction.quarantine` | PENDING |
| M012 | `PXMainDataRestoreTransactionErrorDomain` | 8 / QuarantineFailed | `PXMainDataRestoreTransactionErrorFieldPathKey` | `$.transaction.quarantine` | PENDING |
| M013 | `PXMainDataRestoreTransactionErrorDomain` | 6 / JournalCreationFailed | `PXMainDataRestoreTransactionErrorFieldPathKey` | `$.journal` | PENDING |
| M014 | `PXMainDataRestoreTransactionErrorDomain` | 9 / CommitFailed | `PXMainDataRestoreTransactionErrorFieldPathKey` | `$.transaction.commit` | PENDING |
| M015 | `PXMainDataRestoreTransactionErrorDomain` | 9 / CommitFailed | `PXMainDataRestoreTransactionErrorFieldPathKey` | `$.transaction.commit` | PENDING |
| M016 | `PXMainDataRestoreTransactionErrorDomain` | 6 / JournalCreationFailed | `PXMainDataRestoreTransactionErrorFieldPathKey` | `$.journal` | PENDING |
| M017 | `PXMainDataRestoreTransactionErrorDomain` | 12 / FilesystemChanged | `PXMainDataRestoreTransactionErrorFieldPathKey` | `$.transaction.commit` | PENDING |
| M018 | `PXMainDataRestoreTransactionErrorDomain` | 6 / JournalCreationFailed | `PXMainDataRestoreTransactionErrorFieldPathKey` | `$.journal` | PENDING |
| M019 | `PXMainDataRestoreTransactionErrorDomain` | 10 / RollbackFailed | `PXMainDataRestoreTransactionErrorFieldPathKey` | `$.transaction.rollback.new` | PENDING |
| M020 | `PXMainDataRestoreTransactionErrorDomain` | 10 / RollbackFailed | `PXMainDataRestoreTransactionErrorFieldPathKey` | `$.transaction.rollback.original` | PENDING |
| M021 | `PXMainDataRestoreTransactionErrorDomain` | 10 / RollbackFailed | `PXMainDataRestoreTransactionErrorFieldPathKey` | `$.transaction.rollback` | PENDING |
| M022 | `PXMainDataRestoreTransactionErrorDomain` | 11 / CleanupFailed | `PXMainDataRestoreTransactionErrorFieldPathKey` | `$.transaction.cleanup` | PENDING |
| M023 | none expected | — | — | — | PENDING |
| M024 | none expected | — | — | — | PENDING |
| M025 | none expected | — | — | — | PENDING |
| M026 | none expected | — | — | — | PENDING |
| M027 | none expected | — | — | — | PENDING |
| M028 | none expected | — | — | — | PENDING |
| M029 | none expected | — | — | — | PENDING |
| M030 | none expected | — | — | — | PENDING |
| G001 | none expected | — | — | — | PENDING |
| G002 | `PXAppGroupRestoreTransactionErrorDomain` | 1 / InvalidInput | `PXAppGroupRestoreTransactionErrorFieldPathKey` | `$` | PENDING |
| G003 | `PXAppGroupRestoreTransactionErrorDomain` | 4 / LockFailed | `PXAppGroupRestoreTransactionErrorFieldPathKey` | `$.locks` | PENDING |
| G004 | `PXAppGroupRestoreTransactionErrorDomain` | 4 / LockFailed | `PXAppGroupRestoreTransactionErrorFieldPathKey` | `$.locks` | PENDING |
| G005 | `PXAppGroupRestoreTransactionErrorDomain` | 5 / CrossDeviceBoundary | `PXAppGroupRestoreTransactionErrorFieldPathKey` | `$.stage` | PENDING |
| G006 | none expected | — | — | — | PENDING |
| G007 | `PXAppGroupRestoreTransactionErrorDomain` | 7 / JournalCreationFailed | `PXAppGroupRestoreTransactionErrorFieldPathKey` | `$.journal` | PENDING |
| G008 | `PXAppGroupRestoreTransactionErrorDomain` | 7 / JournalCreationFailed | `PXAppGroupRestoreTransactionErrorFieldPathKey` | `$.journal` | PENDING |
| G009 | `PXAppGroupRestoreTransactionErrorDomain` | 7 / JournalCreationFailed | `PXAppGroupRestoreTransactionErrorFieldPathKey` | `$.journal` | PENDING |
| G010 | `PXAppGroupRestoreTransactionErrorDomain` | 7 / JournalCreationFailed | `PXAppGroupRestoreTransactionErrorFieldPathKey` | `$.journal` | PENDING |
| G011 | `PXAppGroupRestoreTransactionErrorDomain` | 9 / QuarantineFailed | `PXAppGroupRestoreTransactionErrorFieldPathKey` | `$.transaction.quarantine` | PENDING |
| G012 | `PXAppGroupRestoreTransactionErrorDomain` | 9 / QuarantineFailed | `PXAppGroupRestoreTransactionErrorFieldPathKey` | `$.transaction.quarantine` | PENDING |
| G013 | `PXAppGroupRestoreTransactionErrorDomain` | 9 / QuarantineFailed | `PXAppGroupRestoreTransactionErrorFieldPathKey` | `$.transaction.quarantine` | PENDING |
| G014 | `PXAppGroupRestoreTransactionErrorDomain` | 9 / QuarantineFailed | `PXAppGroupRestoreTransactionErrorFieldPathKey` | `$.transaction.quarantine` | PENDING |
| G015 | `PXAppGroupRestoreTransactionErrorDomain` | 10 / CommitFailed | `PXAppGroupRestoreTransactionErrorFieldPathKey` | `$.transaction.commit` | PENDING |
| G016 | `PXAppGroupRestoreTransactionErrorDomain` | 10 / CommitFailed | `PXAppGroupRestoreTransactionErrorFieldPathKey` | `$.transaction.commit` | PENDING |
| G017 | `PXAppGroupRestoreTransactionErrorDomain` | 10 / CommitFailed | `PXAppGroupRestoreTransactionErrorFieldPathKey` | `$.transaction.commit` | PENDING |
| G018 | `PXAppGroupRestoreTransactionErrorDomain` | 10 / CommitFailed | `PXAppGroupRestoreTransactionErrorFieldPathKey` | `$.transaction.commit` | PENDING |
| G019 | `PXAppGroupRestoreTransactionErrorDomain` | 10 / CommitFailed | `PXAppGroupRestoreTransactionErrorFieldPathKey` | `$.transaction.commit` | PENDING |
| G020 | `PXAppGroupRestoreTransactionErrorDomain` | 11 / RollbackFailed | `PXAppGroupRestoreTransactionErrorFieldPathKey` | `$.transaction.rollback` | PENDING |
| G021 | `PXAppGroupRestoreTransactionErrorDomain` | 11 / RollbackFailed | `PXAppGroupRestoreTransactionErrorFieldPathKey` | `$.transaction.rollback` | PENDING |
| G022 | `PXAppGroupRestoreTransactionErrorDomain` | 11 / RollbackFailed | `PXAppGroupRestoreTransactionErrorFieldPathKey` | `$.transaction.rollback` | PENDING |
| G023 | `PXAppGroupRestoreTransactionErrorDomain` | 12 / CleanupFailed | `PXAppGroupRestoreTransactionErrorFieldPathKey` | `$.transaction.cleanup` | PENDING |
| G024 | `PXAppGroupRestoreTransactionErrorDomain` | 12 / CleanupFailed | `PXAppGroupRestoreTransactionErrorFieldPathKey` | `$.transaction.cleanup` | PENDING |
| G025 | none expected | — | — | — | PENDING |
| G026 | none expected | — | — | — | PENDING |
| G027 | none expected | — | — | — | PENDING |
| G028 | none expected | — | — | — | PENDING |
| G029 | none expected | — | — | — | PENDING |
| G030 | none expected | — | — | — | PENDING |
| O001 | none expected | — | — | — | PENDING |
| O002 | `PXOptionalRestoreTransactionErrorDomain` | 1 / InvalidInput | `PXOptionalRestoreTransactionErrorFieldPathKey` | `$` | PENDING |
| O003 | none expected | — | — | — | PENDING |
| O004 | none expected | — | — | — | PENDING |
| O005 | none expected | — | — | — | PENDING |
| O006 | `PXOptionalRestoreTransactionErrorDomain` | 4 / LockFailed | `PXOptionalRestoreTransactionErrorFieldPathKey` | `$.locks` | PENDING |
| O007 | `PXOptionalRestoreTransactionErrorDomain` | 5 / CrossDeviceBoundary | `PXOptionalRestoreTransactionErrorFieldPathKey` | `$.stage` | PENDING |
| O008 | none expected | — | — | — | PENDING |
| O009 | `PXOptionalRestoreTransactionErrorDomain` | 7 / WorkspaceCreationFailed | `PXOptionalRestoreTransactionErrorFieldPathKey` | `$.workspace` | PENDING |
| O010 | `PXOptionalRestoreTransactionErrorDomain` | 8 / ReplacementPreparationFailed | `PXOptionalRestoreTransactionErrorFieldPathKey` | `$.replacement` | PENDING |
| O011 | `PXOptionalRestoreTransactionErrorDomain` | 9 / ReplacementMismatch | `PXOptionalRestoreTransactionErrorFieldPathKey` | `$.replacement` | PENDING |
| O012 | `PXOptionalRestoreTransactionErrorDomain` | 9 / ReplacementMismatch | `PXOptionalRestoreTransactionErrorFieldPathKey` | `$.replacement` | PENDING |
| O013 | `PXOptionalRestoreTransactionErrorDomain` | 9 / ReplacementMismatch | `PXOptionalRestoreTransactionErrorFieldPathKey` | `$.replacement` | PENDING |
| O014 | `PXOptionalRestoreTransactionErrorDomain` | 10 / JournalCreationFailed | `PXOptionalRestoreTransactionErrorFieldPathKey` | `$.journal` | PENDING |
| O015 | `PXOptionalRestoreTransactionErrorDomain` | 12 / QuarantineFailed | `PXOptionalRestoreTransactionErrorFieldPathKey` | `$.transaction.quarantine` | PENDING |
| O016 | `PXOptionalRestoreTransactionErrorDomain` | 12 / QuarantineFailed | `PXOptionalRestoreTransactionErrorFieldPathKey` | `$.transaction.quarantine` | PENDING |
| O017 | `PXOptionalRestoreTransactionErrorDomain` | 12 / QuarantineFailed | `PXOptionalRestoreTransactionErrorFieldPathKey` | `$.transaction.quarantine` | PENDING |
| O018 | `PXOptionalRestoreTransactionErrorDomain` | 10 / JournalCreationFailed | `PXOptionalRestoreTransactionErrorFieldPathKey` | `$.journal` | PENDING |
| O019 | `PXOptionalRestoreTransactionErrorDomain` | 13 / CommitFailed | `PXOptionalRestoreTransactionErrorFieldPathKey` | `$.transaction.commit` | PENDING |
| O020 | `PXOptionalRestoreTransactionErrorDomain` | 13 / CommitFailed | `PXOptionalRestoreTransactionErrorFieldPathKey` | `$.transaction.commit` | PENDING |
| O021 | `PXOptionalRestoreTransactionErrorDomain` | 13 / CommitFailed | `PXOptionalRestoreTransactionErrorFieldPathKey` | `$.transaction.commit` | PENDING |
| O022 | `PXOptionalRestoreTransactionErrorDomain` | 10 / JournalCreationFailed | `PXOptionalRestoreTransactionErrorFieldPathKey` | `$.journal` | PENDING |
| O023 | `PXOptionalRestoreTransactionErrorDomain` | 10 / JournalCreationFailed | `PXOptionalRestoreTransactionErrorFieldPathKey` | `$.journal` | PENDING |
| O024 | `PXOptionalRestoreTransactionErrorDomain` | 14 / RollbackFailed | `PXOptionalRestoreTransactionErrorFieldPathKey` | `$.transaction.rollback.new` | PENDING |
| O025 | `PXOptionalRestoreTransactionErrorDomain` | 14 / RollbackFailed | `PXOptionalRestoreTransactionErrorFieldPathKey` | `$.transaction.rollback.original` | PENDING |
| O026 | `PXOptionalRestoreTransactionErrorDomain` | 15 / CleanupFailed | `PXOptionalRestoreTransactionErrorFieldPathKey` | `$.transaction.cleanup` | PENDING |
| O027 | none expected | — | — | — | PENDING |
| O028 | none expected | — | — | — | PENDING |
| O029 | none expected | — | — | — | PENDING |
| O030 | none expected | — | — | — | PENDING |

## Per-case public transaction state

| ID | Public state | Durable/recovery phase | Runtime |
|---|---|---|---|
| M001 | committed=YES; rollbackPerformed=NO; rollbackComplete=NO; recovered=0 | ordinary in-process case | PENDING |
| M002 | committed remains YES; rollbackPerformed=NO | ordinary in-process case | PENDING |
| M003 | no transaction object | ordinary in-process case | PENDING |
| M004 | no transaction object | ordinary in-process case | PENDING |
| M005 | committed=YES; rollbackPerformed=NO; rollbackComplete=NO; recovered=0 | ordinary in-process case | PENDING |
| M006 | committed=NO; rollbackPerformed=NO; rollbackComplete=NO | ordinary in-process case | PENDING |
| M007 | committed=NO; rollbackPerformed=NO; rollbackComplete=NO | ordinary in-process case | PENDING |
| M008 | committed=NO; rollbackPerformed=NO; rollbackComplete=NO | ordinary in-process case | PENDING |
| M009 | committed=NO; rollbackPerformed=NO; rollbackComplete=NO | ordinary in-process case | PENDING |
| M010 | committed=NO; rollbackPerformed=NO; rollbackComplete=NO | ordinary in-process case | PENDING |
| M011 | committed=NO; rollbackPerformed=YES; rollbackComplete=YES | ordinary in-process case | PENDING |
| M012 | committed=NO; rollbackPerformed=YES; rollbackComplete=YES | ordinary in-process case | PENDING |
| M013 | committed=NO; rollbackPerformed=YES; rollbackComplete=YES | ordinary in-process case | PENDING |
| M014 | committed=NO; rollbackPerformed=YES; rollbackComplete=YES | ordinary in-process case | PENDING |
| M015 | committed=NO; rollbackPerformed=YES; rollbackComplete=YES | ordinary in-process case | PENDING |
| M016 | committed=NO; rollbackPerformed=YES; rollbackComplete=YES | ordinary in-process case | PENDING |
| M017 | committed=NO; rollbackPerformed=YES; rollbackComplete=YES | ordinary in-process case | PENDING |
| M018 | committed=NO; rollbackPerformed=YES; rollbackComplete=YES | ordinary in-process case | PENDING |
| M019 | committed=NO; rollbackPerformed=YES; rollbackComplete=NO | ordinary in-process case | PENDING |
| M020 | committed=NO; rollbackPerformed=YES; rollbackComplete=NO | ordinary in-process case | PENDING |
| M021 | committed=NO; rollbackPerformed=YES; rollbackComplete=NO | ordinary in-process case | PENDING |
| M022 | committed=YES; rollbackPerformed=NO | ordinary in-process case | PENDING |
| M023 | recoveredStaleTransactionCount=1 | prepared | PENDING |
| M024 | recoveredStaleTransactionCount=1 | prepared | PENDING |
| M025 | recoveredStaleTransactionCount=1 | quarantined | PENDING |
| M026 | recoveredStaleTransactionCount=1 | quarantined | PENDING |
| M027 | recoveredStaleTransactionCount=1 | installed | PENDING |
| M028 | recoveredStaleTransactionCount=1 | committed | PENDING |
| M029 | recoveredStaleTransactionCount=1 | rolling-back | PENDING |
| M030 | recoveredStaleTransactionCount=1 | rolled-back | PENDING |
| G001 | committed=YES; rollbackPerformed=NO; rollbackComplete=NO; targetCount=2; recovered=0 | ordinary in-process case | PENDING |
| G002 | committed remains YES | ordinary in-process case | PENDING |
| G003 | no transaction object | ordinary in-process case | PENDING |
| G004 | no transaction object | ordinary in-process case | PENDING |
| G005 | no transaction object | ordinary in-process case | PENDING |
| G006 | committed=YES; rollbackPerformed=NO; rollbackComplete=NO; targetCount=2; recovered=0 | ordinary in-process case | PENDING |
| G007 | committed=NO; rollbackPerformed=NO; rollbackComplete=NO | ordinary in-process case | PENDING |
| G008 | committed=NO; rollbackPerformed=NO; rollbackComplete=NO | ordinary in-process case | PENDING |
| G009 | committed=NO; rollbackPerformed=NO; rollbackComplete=NO | ordinary in-process case | PENDING |
| G010 | committed=NO; rollbackPerformed=NO; rollbackComplete=NO | ordinary in-process case | PENDING |
| G011 | committed=NO; rollbackPerformed=YES; rollbackComplete=YES | ordinary in-process case | PENDING |
| G012 | committed=NO; rollbackPerformed=YES; rollbackComplete=YES | ordinary in-process case | PENDING |
| G013 | committed=NO; rollbackPerformed=YES; rollbackComplete=YES | ordinary in-process case | PENDING |
| G014 | committed=NO; rollbackPerformed=YES; rollbackComplete=YES | ordinary in-process case | PENDING |
| G015 | committed=NO; rollbackPerformed=YES; rollbackComplete=YES | ordinary in-process case | PENDING |
| G016 | committed=NO; rollbackPerformed=YES; rollbackComplete=YES | ordinary in-process case | PENDING |
| G017 | committed=NO; rollbackPerformed=YES; rollbackComplete=YES | ordinary in-process case | PENDING |
| G018 | committed=NO; rollbackPerformed=YES; rollbackComplete=YES | ordinary in-process case | PENDING |
| G019 | committed=NO; rollbackPerformed=YES; rollbackComplete=YES | ordinary in-process case | PENDING |
| G020 | committed=NO; rollbackPerformed=YES; rollbackComplete=NO | ordinary in-process case | PENDING |
| G021 | committed=NO; rollbackPerformed=YES; rollbackComplete=NO | ordinary in-process case | PENDING |
| G022 | committed=NO; rollbackPerformed=YES; rollbackComplete=NO | ordinary in-process case | PENDING |
| G023 | committed=YES; rollbackPerformed=NO | ordinary in-process case | PENDING |
| G024 | committed=YES; rollbackPerformed=NO | ordinary in-process case | PENDING |
| G025 | recoveredStaleBatchCount=1; targetCount=2 | prepared | PENDING |
| G026 | recoveredStaleBatchCount=1; targetCount=2 | prepared | PENDING |
| G027 | recoveredStaleBatchCount=1; targetCount=2 | quarantined | PENDING |
| G028 | recoveredStaleBatchCount=1; targetCount=2 | quarantined | PENDING |
| G029 | recoveredStaleBatchCount=1; targetCount=2 | installed | PENDING |
| G030 | recoveredStaleBatchCount=1; targetCount=2 | committed | PENDING |
| O001 | committed=YES; rollbackPerformed=NO; rollbackComplete=NO; itemCount=3; recovered=0 | ordinary in-process case | PENDING |
| O002 | committed remains YES | ordinary in-process case | PENDING |
| O003 | committed=YES; rollbackPerformed=NO; rollbackComplete=NO; itemCount=1; recovered=0 | ordinary in-process case | PENDING |
| O004 | committed=YES; rollbackPerformed=NO; rollbackComplete=NO; itemCount=1; recovered=0 | ordinary in-process case | PENDING |
| O005 | committed=YES; rollbackPerformed=NO; rollbackComplete=NO; itemCount=1; recovered=0 | ordinary in-process case | PENDING |
| O006 | no transaction object | ordinary in-process case | PENDING |
| O007 | no transaction object | ordinary in-process case | PENDING |
| O008 | committed=YES; rollbackPerformed=NO; rollbackComplete=NO; itemCount=3; recovered=0 | ordinary in-process case | PENDING |
| O009 | committed=NO; rollbackPerformed=NO; rollbackComplete=NO | ordinary in-process case | PENDING |
| O010 | committed=NO; rollbackPerformed=NO; rollbackComplete=NO | ordinary in-process case | PENDING |
| O011 | committed=NO; rollbackPerformed=NO; rollbackComplete=NO | ordinary in-process case | PENDING |
| O012 | committed=NO; rollbackPerformed=NO; rollbackComplete=NO | ordinary in-process case | PENDING |
| O013 | committed=NO; rollbackPerformed=NO; rollbackComplete=NO | ordinary in-process case | PENDING |
| O014 | committed=NO; rollbackPerformed=YES; rollbackComplete=YES | ordinary in-process case | PENDING |
| O015 | committed=NO; rollbackPerformed=YES; rollbackComplete=YES | ordinary in-process case | PENDING |
| O016 | committed=NO; rollbackPerformed=YES; rollbackComplete=YES | ordinary in-process case | PENDING |
| O017 | committed=NO; rollbackPerformed=YES; rollbackComplete=YES | ordinary in-process case | PENDING |
| O018 | committed=NO; rollbackPerformed=YES; rollbackComplete=YES | ordinary in-process case | PENDING |
| O019 | committed=NO; rollbackPerformed=YES; rollbackComplete=YES | ordinary in-process case | PENDING |
| O020 | committed=NO; rollbackPerformed=YES; rollbackComplete=YES | ordinary in-process case | PENDING |
| O021 | committed=NO; rollbackPerformed=YES; rollbackComplete=YES | ordinary in-process case | PENDING |
| O022 | committed=NO; rollbackPerformed=YES; rollbackComplete=YES | ordinary in-process case | PENDING |
| O023 | committed=NO; rollbackPerformed=YES; rollbackComplete=YES | ordinary in-process case | PENDING |
| O024 | committed=NO; rollbackPerformed=YES; rollbackComplete=NO | ordinary in-process case | PENDING |
| O025 | committed=NO; rollbackPerformed=YES; rollbackComplete=NO | ordinary in-process case | PENDING |
| O026 | committed=YES; rollbackPerformed=NO | ordinary in-process case | PENDING |
| O027 | recoveredStaleTransactionCount=1; itemCount=3 | prepared | PENDING |
| O028 | recoveredStaleTransactionCount=1; itemCount=3 | prepared | PENDING |
| O029 | recoveredStaleTransactionCount=1; itemCount=3 | installed | PENDING |
| O030 | recoveredStaleTransactionCount=1; itemCount=3 | committed | PENDING |

## Encoded totals and runtime status

| Category | Encoded | Runtime |
|---|---:|---|
| Self-tests | 96 | PENDING GitHub Actions |
| Transaction cases | 90 | PENDING GitHub Actions |
| SIGKILL crash cases | 18 | PENDING GitHub Actions |
| Fresh-process recovery cases | 18 | PENDING GitHub Actions |
| Rollback-complete cases | 27 | PENDING GitHub Actions |
| Rollback-incomplete cases | 8 | PENDING GitHub Actions |
| Cleanup-warning cases | 4 | PENDING GitHub Actions |

Crash cases are M023–M030, G025–G030 and O027–O030. Rollback-incomplete cases are M019–M021, G020–G022 and O024–O025. Cleanup-warning cases are M022, G023, G024 and O026.

## Local Windows gates

```text
backup_restore_hardening self-test: PASS (49/49)
backup_restore_hardening audit: PASS (1711/1711)
archive fixture generator self-test: PASS (86/86)
git diff --check: PASS
```

No Objective-C compile, transaction runtime, no-mutation runtime, application package or device test is claimed on Windows.

## macOS/GitHub and Apple status

| Gate | Status |
|---|---|
| PXResolvedContainer.m compile | PENDING GitHub Actions/device evidence |
| Main transaction compile | PENDING GitHub Actions/device evidence |
| Main harness compile | PENDING GitHub Actions/device evidence |
| Main self-tests 32/32 | PENDING GitHub Actions/device evidence |
| Main cases 30/30 | PENDING GitHub Actions/device evidence |
| App Group transaction compile | PENDING GitHub Actions/device evidence |
| App Group harness compile | PENDING GitHub Actions/device evidence |
| App Group self-tests 32/32 | PENDING GitHub Actions/device evidence |
| App Group cases 30/30 | PENDING GitHub Actions/device evidence |
| Optional transaction compile | PENDING GitHub Actions/device evidence |
| Optional harness compile | PENDING GitHub Actions/device evidence |
| Optional self-tests 32/32 | PENDING GitHub Actions/device evidence |
| Optional cases 30/30 | PENDING GitHub Actions/device evidence |
| TASK-6.4 archive harness | PENDING GitHub Actions/device evidence |
| Apple application build status | PENDING GitHub Actions/device evidence |
| Device-test status | PENDING GitHub Actions/device evidence |

## Workflow exact diff and hash

The fail-closed block follows TASK-6.4 archive fixtures and precedes Homebrew/Theos. It compiles the real transactions with the prelude, the harness without the prelude, runs all three 32-test self-test suites and all three 30-case transaction suites, and contains no retry, subset, conditional skip, continue-on-error or allow-failure.

- Workflow bytes: 7156.
- Workflow SHA-256: `d2f85fd8e11c4ea1ab554cfdd1da602226e593ce471d5bfb1c1f20cd0aae0830`.
- CRLF: 167; LF-only: 0; NUL: 0; final CRLF present.

## Static-audit delta and eight new guards

- TASK-6.4 audit: 1703/1703.
- TASK-6.5 audit: 1711/1711.
- Delta: +8 from exactly the prelude and harness.
- Static self-tests remain 49/49; audit script is unchanged; tests/ remains included.

- `BRH-ENV-FILE-TESTS-BACKUP-RESTORE-HARDENING-PXTRANSACTIONFAULTINJECTIONPRELUDE-H-BYTES`
- `BRH-ENV-FILE-TESTS-BACKUP-RESTORE-HARDENING-PXTRANSACTIONFAULTINJECTIONPRELUDE-H-UTF8`
- `BRH-ENV-FILE-TESTS-BACKUP-RESTORE-HARDENING-PXTRANSACTIONFAULTINJECTIONPRELUDE-H-NUL`
- `BRH-ENV-FILE-TESTS-BACKUP-RESTORE-HARDENING-PXTRANSACTIONFAULTINJECTIONPRELUDE-H-CONFLICT`
- `BRH-ENV-FILE-TESTS-BACKUP-RESTORE-HARDENING-PXTRANSACTIONFAULTHARNESS-M-BYTES`
- `BRH-ENV-FILE-TESTS-BACKUP-RESTORE-HARDENING-PXTRANSACTIONFAULTHARNESS-M-UTF8`
- `BRH-ENV-FILE-TESTS-BACKUP-RESTORE-HARDENING-PXTRANSACTIONFAULTHARNESS-M-NUL`
- `BRH-ENV-FILE-TESTS-BACKUP-RESTORE-HARDENING-PXTRANSACTIONFAULTHARNESS-M-CONFLICT`

## Changed-file hashes and line endings

| Path | Bytes | SHA-256 |
|---|---:|---|
| `tests/backup-restore-hardening/PXTransactionFaultInjectionPrelude.h` | 2116 | `b6ca7d9c657e1f99298c16b98be75ba8944e8f9fdd3b60fba5cbc007f4f7bc86` |
| `tests/backup-restore-hardening/PXTransactionFaultHarness.m` | 185415 | `c2c0d670e9a30ef13c63e4ff7e0b70b747720748a76d698392637c58f813fa48` |
| `.github/workflows/build-ios-arm.yml` | 7156 | `d2f85fd8e11c4ea1ab554cfdd1da602226e593ce471d5bfb1c1f20cd0aae0830` |

Prelude and harness are UTF-8 LF; workflow is UTF-8 CRLF-only; report is UTF-8 LF. All have no BOM, no NUL and a final newline.

## Protected production and integration hashes

| Path | Bytes | SHA-256 |
|---|---:|---|
| `PXMainDataRestoreTransaction.h` | 2061 | `df444b03e0214d62e31c89094f7e0afe1037255ab6582928a608ec839466a575` |
| `PXMainDataRestoreTransaction.m` | 115847 | `894c40ab599074bc6c481a5b9084c3d557c64fb101336f0495d5297234a5f3c5` |
| `PXAppGroupRestoreTransaction.h` | 2235 | `cd329b3f67433214b36d195719e337cc951204c774dd65bbe379eb8936a33412` |
| `PXAppGroupRestoreTransaction.m` | 138376 | `842bf9676fdac4c31433f966b81b2b93c82d03225d7f046d7e464a3b402bfbd6` |
| `PXOptionalRestoreTransaction.h` | 4050 | `1d162e411824a708209c78325385cff75cea453a8097c93347f02cfb8bf2ad78` |
| `PXOptionalRestoreTransaction.m` | 240408 | `b766f73f7b49877ab589f35ae9dc7d0f89e80638526e6c5663777ac6a1a48c1c` |
| `PXResolvedContainer.h` | 1691 | `6ba935cb659ebdc5fdb8a96b13dd9f1450acb2e284267ac82e8890287a686718` |
| `PXResolvedContainer.m` | 5304 | `a782089c0605f8d7803ffb53f746a585afb85f3ffbc9ed111f00575d77ada8fb` |
| `PXMainDataStaging.h` | 2511 | `2eaea45c166986c419b32074141e8e1f7ab6000f153e860b10b48e1405620554` |
| `PXOptionalRestoreStaging.h` | 4355 | `3d594d5f2eb509e2fb9e87849013ec9428ef7083eb0c4b52ecffe00fa56809c3` |
| `PXAppGroupRestoreTargetPlan.h` | 2039 | `565924464aafb15836a4506de0336f62c2eb0986f7fa7ebd1839d98c48e888d3` |
| `PXDestructivePathValidator.h` | 1213 | `542e158a4f04bf50125e0064fbebf02ac32f1de07508c3f32058e770f75a3c0a` |
| `AppDataBackupManager.h` | 1442 | `b19c1c61e6df642468d713dede5a0c0bd0dbb6a0ac72d98ad6878d3cae1f2e75` |
| `AppDataBackupManager.m` | 239969 | `61fc1ff901d64a0b2732c1ea44f47f23209a0b55404fbc69e27889ee03939028` |
| `PXRestoreResult.h` | 4512 | `cb7f2f3e40b3414d329405b1802bf6a9f245f1b660ca983d04776c0af449e69d` |
| `PXRestoreResult.m` | 15842 | `c698a854589731f0987379c324d02729f3b586fd0ac3575f9798b77d6207c2fb` |
| `Makefile` | 9266 | `b2d9ca1083f85b818f132612e792c73e94e78390ef06092db2075439af945dfa` |
| `scripts/audit_backup_restore_hardening.py` | 94957 | `19e1ea53fad0668256d45bb31e0323cda4133af92c39b0c7bad584dc9ac0c745` |
| `tests/backup-restore-hardening/generate_archive_fixtures.py` | 43013 | `99fdf4bdc5df8a9a3f09f01946a718eade721c56ad405b5ad6bb0ea793f2044d` |
| `tests/backup-restore-hardening/PXArchiveFixtureHarness.m` | 33189 | `c57f396190cafbdcadd55be2d8d215ab612a5bd02489a7d0aa1d04ebc1a99829` |
| `docs/backup-restore-hardening/reports/TASK-6.4-REPORT.md` | 105005 | `7340799b8164dec5679ff8373182f06f2cc4cd816dde4a2da156f45321942924` |

All protected files remain byte-identical. Production source drift is zero.

## Synthetic-fault accuracy and residual limitations

Synthetic `st_dev`, ENOSPC, EIO, EMFILE, EINTR and SIGKILL are labelled as test injection. TASK-6.5 does not prove real cross-volume APFS behavior, device lock-state behavior, actual disk exhaustion, kernel-level I/O corruption, power loss between hardware cache flushes, iOS file-protection interactions, Keychain transaction behavior or backup publication race behavior. The test-only destructive validator isolates transaction behavior and does not retest the production validator.

## Explicit numbered scenarios

0001. Baseline HEAD equals the required TASK-6.4 implementation commit.
0002. TASK-6.4 protected report remains 105005 bytes and unchanged.
0003. TASK-6.4 protected report scenario count is corrected to 1222.
0004. TASK-6.4 review absence is accepted by user authority.
0005. Authorized scope contains exactly four implementation files.
0006. No production transaction source is modified.
0007. No resolver or staging source is modified.
0008. No manager, result, Makefile or audit source is modified.
0009. No TASK-6.4 test artifact is modified.
0010. No Keychain or backup-publication source is included.
0011. Prelude has exactly 20 wrapper declarations and redirects.
0012. Harness has exactly 20 wrapper implementations.
0013. Open and openat variadic forms are preserved.
0014. Fcntl no-argument and integer-argument forms are preserved.
0015. Fail-before, fail-after-close and bounded EINTR are encoded.
0016. Synthetic successful fstat device mutation is encoded.
0017. Crash-before and crash-after-success use SIGKILL.
0018. Descriptor and DIR role lifecycle is tracked.
0019. Journal and transaction event numbering is deterministic.
0020. Fresh child spawn, wait and recovery are encoded.
0021. Filesystem snapshots and output privacy are encoded.
0022. Four Optional fixed digest vectors are encoded.
0023. Main, App Group and Optional each encode 30 ordered cases.
0024. Main and App Group link real PXResolvedContainer.
0025. Optional preserves all three distinct item kinds.
0026. Keychain remains outside the Optional transaction domain.
0027. Static self-tests pass 49/49.
0028. Repository audit passes 1711/1711.
0029. Archive generator passes 86/86.
0030. Workflow bytes, hash and CRLF match exactly.
0031. Generated executables, objects, journals and snapshots are not committed.
0032. Coordinator documents remain preserved.
0033. No TASK-6.5 review or TASK-6.6 work is created.
0034. No push is performed.
0035. macOS compile/runtime remains pending.
0036. Apple build and device testing remain pending.
0037. M001 occurs at the exact deterministic matrix position.
0038. M001 encodes clean commit.
0039. M001 invokes the unchanged production authority.
0040. M001 uses one fresh root and fixed fixture data.
0041. M001 confines mutations below the case root.
0042. M001 expected call result is commit YES; error nil; cleanupWarning nil.
0043. M001 expected public state is committed=YES; rollbackPerformed=NO; rollbackComplete=NO; recovered=0.
0044. M001 expected filesystem state is INSTALLED; workspace absent.
0045. M001 rejects false committed completion.
0046. M001 rejects false rollback completion.
0047. M001 rejects unapproved MIXED state.
0048. M001 asserts privacy separately from code matching.
0049. M001 asserts lock and descriptor hygiene.
0050. M001 uses deterministic failure ordering.
0051. M001 accepts no field prefix or alternate field.
0052. M001 does not patch production to pass.
0053. M001 runtime result remains PENDING GitHub Actions.
0054. M001 generated artifacts remain outside Git.
0055. M001 expects no ordinary NSError contract.
0056. M001 accepts no any-error match.
0057. M001 accepts no fallback error category.
0058. M001 retains exact success or crash/recovery assertions.
0059. M002 occurs at the exact deterministic matrix position.
0060. M002 encodes second commit on same object.
0061. M002 invokes the unchanged production authority.
0062. M002 uses one fresh root and fixed fixture data.
0063. M002 confines mutations below the case root.
0064. M002 expected call result is second commit NO.
0065. M002 expected public state is committed remains YES; rollbackPerformed=NO.
0066. M002 expected filesystem state is INSTALLED unchanged.
0067. M002 rejects false committed completion.
0068. M002 rejects false rollback completion.
0069. M002 rejects unapproved MIXED state.
0070. M002 asserts privacy separately from code matching.
0071. M002 asserts lock and descriptor hygiene.
0072. M002 uses deterministic failure ordering.
0073. M002 accepts no field prefix or alternate field.
0074. M002 does not patch production to pass.
0075. M002 runtime result remains PENDING GitHub Actions.
0076. M002 generated artifacts remain outside Git.
0077. M002 exact domain is PXMainDataRestoreTransactionErrorDomain.
0078. M002 exact code is 1 (InvalidInput).
0079. M002 exact field is $.transaction.
0080. M002 uses field key PXMainDataRestoreTransactionErrorFieldPathKey.
0081. M003 occurs at the exact deterministic matrix position.
0082. M003 encodes real competing flock on target.
0083. M003 invokes the unchanged production authority.
0084. M003 uses one fresh root and fixed fixture data.
0085. M003 confines mutations below the case root.
0086. M003 expected call result is factory nil.
0087. M003 expected public state is no transaction object.
0088. M003 expected filesystem state is ORIGINAL; no workspace.
0089. M003 rejects false committed completion.
0090. M003 rejects false rollback completion.
0091. M003 rejects unapproved MIXED state.
0092. M003 asserts privacy separately from code matching.
0093. M003 asserts lock and descriptor hygiene.
0094. M003 uses deterministic failure ordering.
0095. M003 accepts no field prefix or alternate field.
0096. M003 does not patch production to pass.
0097. M003 runtime result remains PENDING GitHub Actions.
0098. M003 generated artifacts remain outside Git.
0099. M003 exact domain is PXMainDataRestoreTransactionErrorDomain.
0100. M003 exact code is 3 (FilesystemInspectionFailed).
0101. M003 exact field is $.destination.
0102. M003 uses field key PXMainDataRestoreTransactionErrorFieldPathKey.
0103. M004 occurs at the exact deterministic matrix position.
0104. M004 encodes mutate stage st_dev.
0105. M004 invokes the unchanged production authority.
0106. M004 uses one fresh root and fixed fixture data.
0107. M004 confines mutations below the case root.
0108. M004 expected call result is factory nil.
0109. M004 expected public state is no transaction object.
0110. M004 expected filesystem state is ORIGINAL; no workspace.
0111. M004 rejects false committed completion.
0112. M004 rejects false rollback completion.
0113. M004 rejects unapproved MIXED state.
0114. M004 asserts privacy separately from code matching.
0115. M004 asserts lock and descriptor hygiene.
0116. M004 uses deterministic failure ordering.
0117. M004 accepts no field prefix or alternate field.
0118. M004 does not patch production to pass.
0119. M004 runtime result remains PENDING GitHub Actions.
0120. M004 generated artifacts remain outside Git.
0121. M004 exact domain is PXMainDataRestoreTransactionErrorDomain.
0122. M004 exact code is 4 (CrossDeviceBoundary).
0123. M004 exact field is $.stage.
0124. M004 uses field key PXMainDataRestoreTransactionErrorFieldPathKey.
0125. M005 occurs at the exact deterministic matrix position.
0126. M005 encodes one EINTR on prepared journal write.
0127. M005 invokes the unchanged production authority.
0128. M005 uses one fresh root and fixed fixture data.
0129. M005 confines mutations below the case root.
0130. M005 expected call result is commit YES; error nil; cleanupWarning nil.
0131. M005 expected public state is committed=YES; rollbackPerformed=NO; rollbackComplete=NO; recovered=0.
0132. M005 expected filesystem state is INSTALLED; workspace absent.
0133. M005 rejects false committed completion.
0134. M005 rejects false rollback completion.
0135. M005 rejects unapproved MIXED state.
0136. M005 asserts privacy separately from code matching.
0137. M005 asserts lock and descriptor hygiene.
0138. M005 uses deterministic failure ordering.
0139. M005 accepts no field prefix or alternate field.
0140. M005 does not patch production to pass.
0141. M005 runtime result remains PENDING GitHub Actions.
0142. M005 generated artifacts remain outside Git.
0143. M005 expects no ordinary NSError contract.
0144. M005 accepts no any-error match.
0145. M005 accepts no fallback error category.
0146. M005 retains exact success or crash/recovery assertions.
0147. M006 occurs at the exact deterministic matrix position.
0148. M006 encodes prepared journal temporary open fails ENOSPC.
0149. M006 invokes the unchanged production authority.
0150. M006 uses one fresh root and fixed fixture data.
0151. M006 confines mutations below the case root.
0152. M006 expected call result is commit NO.
0153. M006 expected public state is committed=NO; rollbackPerformed=NO; rollbackComplete=NO.
0154. M006 expected filesystem state is ORIGINAL; workspace absent.
0155. M006 rejects false committed completion.
0156. M006 rejects false rollback completion.
0157. M006 rejects unapproved MIXED state.
0158. M006 asserts privacy separately from code matching.
0159. M006 asserts lock and descriptor hygiene.
0160. M006 uses deterministic failure ordering.
0161. M006 accepts no field prefix or alternate field.
0162. M006 does not patch production to pass.
0163. M006 runtime result remains PENDING GitHub Actions.
0164. M006 generated artifacts remain outside Git.
0165. M006 exact domain is PXMainDataRestoreTransactionErrorDomain.
0166. M006 exact code is 6 (JournalCreationFailed).
0167. M006 exact field is $.journal.
0168. M006 uses field key PXMainDataRestoreTransactionErrorFieldPathKey.
0169. M007 occurs at the exact deterministic matrix position.
0170. M007 encodes prepared journal write fails ENOSPC.
0171. M007 invokes the unchanged production authority.
0172. M007 uses one fresh root and fixed fixture data.
0173. M007 confines mutations below the case root.
0174. M007 expected call result is commit NO.
0175. M007 expected public state is committed=NO; rollbackPerformed=NO; rollbackComplete=NO.
0176. M007 expected filesystem state is ORIGINAL; workspace absent.
0177. M007 rejects false committed completion.
0178. M007 rejects false rollback completion.
0179. M007 rejects unapproved MIXED state.
0180. M007 asserts privacy separately from code matching.
0181. M007 asserts lock and descriptor hygiene.
0182. M007 uses deterministic failure ordering.
0183. M007 accepts no field prefix or alternate field.
0184. M007 does not patch production to pass.
0185. M007 runtime result remains PENDING GitHub Actions.
0186. M007 generated artifacts remain outside Git.
0187. M007 exact domain is PXMainDataRestoreTransactionErrorDomain.
0188. M007 exact code is 6 (JournalCreationFailed).
0189. M007 exact field is $.journal.
0190. M007 uses field key PXMainDataRestoreTransactionErrorFieldPathKey.
0191. M008 occurs at the exact deterministic matrix position.
0192. M008 encodes prepared journal temporary-file fsync fails EIO.
0193. M008 invokes the unchanged production authority.
0194. M008 uses one fresh root and fixed fixture data.
0195. M008 confines mutations below the case root.
0196. M008 expected call result is commit NO.
0197. M008 expected public state is committed=NO; rollbackPerformed=NO; rollbackComplete=NO.
0198. M008 expected filesystem state is ORIGINAL; workspace absent.
0199. M008 rejects false committed completion.
0200. M008 rejects false rollback completion.
0201. M008 rejects unapproved MIXED state.
0202. M008 asserts privacy separately from code matching.
0203. M008 asserts lock and descriptor hygiene.
0204. M008 uses deterministic failure ordering.
0205. M008 accepts no field prefix or alternate field.
0206. M008 does not patch production to pass.
0207. M008 runtime result remains PENDING GitHub Actions.
0208. M008 generated artifacts remain outside Git.
0209. M008 exact domain is PXMainDataRestoreTransactionErrorDomain.
0210. M008 exact code is 6 (JournalCreationFailed).
0211. M008 exact field is $.journal.
0212. M008 uses field key PXMainDataRestoreTransactionErrorFieldPathKey.
0213. M009 occurs at the exact deterministic matrix position.
0214. M009 encodes prepared journal close reports EIO after real close.
0215. M009 invokes the unchanged production authority.
0216. M009 uses one fresh root and fixed fixture data.
0217. M009 confines mutations below the case root.
0218. M009 expected call result is commit NO.
0219. M009 expected public state is committed=NO; rollbackPerformed=NO; rollbackComplete=NO.
0220. M009 expected filesystem state is ORIGINAL; workspace absent.
0221. M009 rejects false committed completion.
0222. M009 rejects false rollback completion.
0223. M009 rejects unapproved MIXED state.
0224. M009 asserts privacy separately from code matching.
0225. M009 asserts lock and descriptor hygiene.
0226. M009 uses deterministic failure ordering.
0227. M009 accepts no field prefix or alternate field.
0228. M009 does not patch production to pass.
0229. M009 runtime result remains PENDING GitHub Actions.
0230. M009 generated artifacts remain outside Git.
0231. M009 exact domain is PXMainDataRestoreTransactionErrorDomain.
0232. M009 exact code is 6 (JournalCreationFailed).
0233. M009 exact field is $.journal.
0234. M009 uses field key PXMainDataRestoreTransactionErrorFieldPathKey.
0235. M010 occurs at the exact deterministic matrix position.
0236. M010 encodes prepared journal publication rename fails EIO.
0237. M010 invokes the unchanged production authority.
0238. M010 uses one fresh root and fixed fixture data.
0239. M010 confines mutations below the case root.
0240. M010 expected call result is commit NO.
0241. M010 expected public state is committed=NO; rollbackPerformed=NO; rollbackComplete=NO.
0242. M010 expected filesystem state is ORIGINAL; workspace absent.
0243. M010 rejects false committed completion.
0244. M010 rejects false rollback completion.
0245. M010 rejects unapproved MIXED state.
0246. M010 asserts privacy separately from code matching.
0247. M010 asserts lock and descriptor hygiene.
0248. M010 uses deterministic failure ordering.
0249. M010 accepts no field prefix or alternate field.
0250. M010 does not patch production to pass.
0251. M010 runtime result remains PENDING GitHub Actions.
0252. M010 generated artifacts remain outside Git.
0253. M010 exact domain is PXMainDataRestoreTransactionErrorDomain.
0254. M010 exact code is 6 (JournalCreationFailed).
0255. M010 exact field is $.journal.
0256. M010 uses field key PXMainDataRestoreTransactionErrorFieldPathKey.
0257. M011 occurs at the exact deterministic matrix position.
0258. M011 encodes first target-to-original rename fails.
0259. M011 invokes the unchanged production authority.
0260. M011 uses one fresh root and fixed fixture data.
0261. M011 confines mutations below the case root.
0262. M011 expected call result is commit NO.
0263. M011 expected public state is committed=NO; rollbackPerformed=YES; rollbackComplete=YES.
0264. M011 expected filesystem state is ORIGINAL; no mixed state; workspace cleaned.
0265. M011 rejects false committed completion.
0266. M011 rejects false rollback completion.
0267. M011 rejects unapproved MIXED state.
0268. M011 asserts privacy separately from code matching.
0269. M011 asserts lock and descriptor hygiene.
0270. M011 uses deterministic failure ordering.
0271. M011 accepts no field prefix or alternate field.
0272. M011 does not patch production to pass.
0273. M011 runtime result remains PENDING GitHub Actions.
0274. M011 generated artifacts remain outside Git.
0275. M011 exact domain is PXMainDataRestoreTransactionErrorDomain.
0276. M011 exact code is 8 (QuarantineFailed).
0277. M011 exact field is $.transaction.quarantine.
0278. M011 uses field key PXMainDataRestoreTransactionErrorFieldPathKey.
0279. M012 occurs at the exact deterministic matrix position.
0280. M012 encodes quarantine directory sync fails.
0281. M012 invokes the unchanged production authority.
0282. M012 uses one fresh root and fixed fixture data.
0283. M012 confines mutations below the case root.
0284. M012 expected call result is commit NO.
0285. M012 expected public state is committed=NO; rollbackPerformed=YES; rollbackComplete=YES.
0286. M012 expected filesystem state is ORIGINAL; no mixed state; workspace cleaned.
0287. M012 rejects false committed completion.
0288. M012 rejects false rollback completion.
0289. M012 rejects unapproved MIXED state.
0290. M012 asserts privacy separately from code matching.
0291. M012 asserts lock and descriptor hygiene.
0292. M012 uses deterministic failure ordering.
0293. M012 accepts no field prefix or alternate field.
0294. M012 does not patch production to pass.
0295. M012 runtime result remains PENDING GitHub Actions.
0296. M012 generated artifacts remain outside Git.
0297. M012 exact domain is PXMainDataRestoreTransactionErrorDomain.
0298. M012 exact code is 8 (QuarantineFailed).
0299. M012 exact field is $.transaction.quarantine.
0300. M012 uses field key PXMainDataRestoreTransactionErrorFieldPathKey.
0301. M013 occurs at the exact deterministic matrix position.
0302. M013 encodes quarantined journal publication fails.
0303. M013 invokes the unchanged production authority.
0304. M013 uses one fresh root and fixed fixture data.
0305. M013 confines mutations below the case root.
0306. M013 expected call result is commit NO.
0307. M013 expected public state is committed=NO; rollbackPerformed=YES; rollbackComplete=YES.
0308. M013 expected filesystem state is ORIGINAL; rollback cleanup complete.
0309. M013 rejects false committed completion.
0310. M013 rejects false rollback completion.
0311. M013 rejects unapproved MIXED state.
0312. M013 asserts privacy separately from code matching.
0313. M013 asserts lock and descriptor hygiene.
0314. M013 uses deterministic failure ordering.
0315. M013 accepts no field prefix or alternate field.
0316. M013 does not patch production to pass.
0317. M013 runtime result remains PENDING GitHub Actions.
0318. M013 generated artifacts remain outside Git.
0319. M013 exact domain is PXMainDataRestoreTransactionErrorDomain.
0320. M013 exact code is 6 (JournalCreationFailed).
0321. M013 exact field is $.journal.
0322. M013 uses field key PXMainDataRestoreTransactionErrorFieldPathKey.
0323. M014 occurs at the exact deterministic matrix position.
0324. M014 encodes first stage-to-target rename fails.
0325. M014 invokes the unchanged production authority.
0326. M014 uses one fresh root and fixed fixture data.
0327. M014 confines mutations below the case root.
0328. M014 expected call result is commit NO.
0329. M014 expected public state is committed=NO; rollbackPerformed=YES; rollbackComplete=YES.
0330. M014 expected filesystem state is ORIGINAL; no mixed state; workspace cleaned.
0331. M014 rejects false committed completion.
0332. M014 rejects false rollback completion.
0333. M014 rejects unapproved MIXED state.
0334. M014 asserts privacy separately from code matching.
0335. M014 asserts lock and descriptor hygiene.
0336. M014 uses deterministic failure ordering.
0337. M014 accepts no field prefix or alternate field.
0338. M014 does not patch production to pass.
0339. M014 runtime result remains PENDING GitHub Actions.
0340. M014 generated artifacts remain outside Git.
0341. M014 exact domain is PXMainDataRestoreTransactionErrorDomain.
0342. M014 exact code is 9 (CommitFailed).
0343. M014 exact field is $.transaction.commit.
0344. M014 uses field key PXMainDataRestoreTransactionErrorFieldPathKey.
0345. M015 occurs at the exact deterministic matrix position.
0346. M015 encodes install target/stage sync fails.
0347. M015 invokes the unchanged production authority.
0348. M015 uses one fresh root and fixed fixture data.
0349. M015 confines mutations below the case root.
0350. M015 expected call result is commit NO.
0351. M015 expected public state is committed=NO; rollbackPerformed=YES; rollbackComplete=YES.
0352. M015 expected filesystem state is ORIGINAL; no mixed state; workspace cleaned.
0353. M015 rejects false committed completion.
0354. M015 rejects false rollback completion.
0355. M015 rejects unapproved MIXED state.
0356. M015 asserts privacy separately from code matching.
0357. M015 asserts lock and descriptor hygiene.
0358. M015 uses deterministic failure ordering.
0359. M015 accepts no field prefix or alternate field.
0360. M015 does not patch production to pass.
0361. M015 runtime result remains PENDING GitHub Actions.
0362. M015 generated artifacts remain outside Git.
0363. M015 exact domain is PXMainDataRestoreTransactionErrorDomain.
0364. M015 exact code is 9 (CommitFailed).
0365. M015 exact field is $.transaction.commit.
0366. M015 uses field key PXMainDataRestoreTransactionErrorFieldPathKey.
0367. M016 occurs at the exact deterministic matrix position.
0368. M016 encodes installed journal publication fails.
0369. M016 invokes the unchanged production authority.
0370. M016 uses one fresh root and fixed fixture data.
0371. M016 confines mutations below the case root.
0372. M016 expected call result is commit NO.
0373. M016 expected public state is committed=NO; rollbackPerformed=YES; rollbackComplete=YES.
0374. M016 expected filesystem state is ORIGINAL; rollback cleanup complete.
0375. M016 rejects false committed completion.
0376. M016 rejects false rollback completion.
0377. M016 rejects unapproved MIXED state.
0378. M016 asserts privacy separately from code matching.
0379. M016 asserts lock and descriptor hygiene.
0380. M016 uses deterministic failure ordering.
0381. M016 accepts no field prefix or alternate field.
0382. M016 does not patch production to pass.
0383. M016 runtime result remains PENDING GitHub Actions.
0384. M016 generated artifacts remain outside Git.
0385. M016 exact domain is PXMainDataRestoreTransactionErrorDomain.
0386. M016 exact code is 6 (JournalCreationFailed).
0387. M016 exact field is $.journal.
0388. M016 uses field key PXMainDataRestoreTransactionErrorFieldPathKey.
0389. M017 occurs at the exact deterministic matrix position.
0390. M017 encodes final test validator rejects target.
0391. M017 invokes the unchanged production authority.
0392. M017 uses one fresh root and fixed fixture data.
0393. M017 confines mutations below the case root.
0394. M017 expected call result is commit NO.
0395. M017 expected public state is committed=NO; rollbackPerformed=YES; rollbackComplete=YES.
0396. M017 expected filesystem state is ORIGINAL; no mixed state; workspace cleaned.
0397. M017 rejects false committed completion.
0398. M017 rejects false rollback completion.
0399. M017 rejects unapproved MIXED state.
0400. M017 asserts privacy separately from code matching.
0401. M017 asserts lock and descriptor hygiene.
0402. M017 uses deterministic failure ordering.
0403. M017 accepts no field prefix or alternate field.
0404. M017 does not patch production to pass.
0405. M017 runtime result remains PENDING GitHub Actions.
0406. M017 generated artifacts remain outside Git.
0407. M017 exact domain is PXMainDataRestoreTransactionErrorDomain.
0408. M017 exact code is 12 (FilesystemChanged).
0409. M017 exact field is $.transaction.commit.
0410. M017 uses field key PXMainDataRestoreTransactionErrorFieldPathKey.
0411. M018 occurs at the exact deterministic matrix position.
0412. M018 encodes committed journal publication fails.
0413. M018 invokes the unchanged production authority.
0414. M018 uses one fresh root and fixed fixture data.
0415. M018 confines mutations below the case root.
0416. M018 expected call result is commit NO.
0417. M018 expected public state is committed=NO; rollbackPerformed=YES; rollbackComplete=YES.
0418. M018 expected filesystem state is ORIGINAL; rollback cleanup complete.
0419. M018 rejects false committed completion.
0420. M018 rejects false rollback completion.
0421. M018 rejects unapproved MIXED state.
0422. M018 asserts privacy separately from code matching.
0423. M018 asserts lock and descriptor hygiene.
0424. M018 uses deterministic failure ordering.
0425. M018 accepts no field prefix or alternate field.
0426. M018 does not patch production to pass.
0427. M018 runtime result remains PENDING GitHub Actions.
0428. M018 generated artifacts remain outside Git.
0429. M018 exact domain is PXMainDataRestoreTransactionErrorDomain.
0430. M018 exact code is 6 (JournalCreationFailed).
0431. M018 exact field is $.journal.
0432. M018 uses field key PXMainDataRestoreTransactionErrorFieldPathKey.
0433. M019 occurs at the exact deterministic matrix position.
0434. M019 encodes rollback target-to-new rename fails.
0435. M019 invokes the unchanged production authority.
0436. M019 uses one fresh root and fixed fixture data.
0437. M019 confines mutations below the case root.
0438. M019 expected call result is commit NO.
0439. M019 expected public state is committed=NO; rollbackPerformed=YES; rollbackComplete=NO.
0440. M019 expected filesystem state is ROLLBACK_EVIDENCE retained; no false completion.
0441. M019 rejects false committed completion.
0442. M019 rejects false rollback completion.
0443. M019 rejects unapproved MIXED state.
0444. M019 asserts privacy separately from code matching.
0445. M019 asserts lock and descriptor hygiene.
0446. M019 uses deterministic failure ordering.
0447. M019 accepts no field prefix or alternate field.
0448. M019 does not patch production to pass.
0449. M019 runtime result remains PENDING GitHub Actions.
0450. M019 generated artifacts remain outside Git.
0451. M019 exact domain is PXMainDataRestoreTransactionErrorDomain.
0452. M019 exact code is 10 (RollbackFailed).
0453. M019 exact field is $.transaction.rollback.new.
0454. M019 uses field key PXMainDataRestoreTransactionErrorFieldPathKey.
0455. M020 occurs at the exact deterministic matrix position.
0456. M020 encodes rollback original-to-target rename fails.
0457. M020 invokes the unchanged production authority.
0458. M020 uses one fresh root and fixed fixture data.
0459. M020 confines mutations below the case root.
0460. M020 expected call result is commit NO.
0461. M020 expected public state is committed=NO; rollbackPerformed=YES; rollbackComplete=NO.
0462. M020 expected filesystem state is ROLLBACK_EVIDENCE retained; no false completion.
0463. M020 rejects false committed completion.
0464. M020 rejects false rollback completion.
0465. M020 rejects unapproved MIXED state.
0466. M020 asserts privacy separately from code matching.
0467. M020 asserts lock and descriptor hygiene.
0468. M020 uses deterministic failure ordering.
0469. M020 accepts no field prefix or alternate field.
0470. M020 does not patch production to pass.
0471. M020 runtime result remains PENDING GitHub Actions.
0472. M020 generated artifacts remain outside Git.
0473. M020 exact domain is PXMainDataRestoreTransactionErrorDomain.
0474. M020 exact code is 10 (RollbackFailed).
0475. M020 exact field is $.transaction.rollback.original.
0476. M020 uses field key PXMainDataRestoreTransactionErrorFieldPathKey.
0477. M021 occurs at the exact deterministic matrix position.
0478. M021 encodes rolled-back journal publication fails.
0479. M021 invokes the unchanged production authority.
0480. M021 uses one fresh root and fixed fixture data.
0481. M021 confines mutations below the case root.
0482. M021 expected call result is commit NO.
0483. M021 expected public state is committed=NO; rollbackPerformed=YES; rollbackComplete=NO.
0484. M021 expected filesystem state is ROLLBACK_EVIDENCE retained; no false completion.
0485. M021 rejects false committed completion.
0486. M021 rejects false rollback completion.
0487. M021 rejects unapproved MIXED state.
0488. M021 asserts privacy separately from code matching.
0489. M021 asserts lock and descriptor hygiene.
0490. M021 uses deterministic failure ordering.
0491. M021 accepts no field prefix or alternate field.
0492. M021 does not patch production to pass.
0493. M021 runtime result remains PENDING GitHub Actions.
0494. M021 generated artifacts remain outside Git.
0495. M021 exact domain is PXMainDataRestoreTransactionErrorDomain.
0496. M021 exact code is 10 (RollbackFailed).
0497. M021 exact field is $.transaction.rollback.
0498. M021 uses field key PXMainDataRestoreTransactionErrorFieldPathKey.
0499. M022 occurs at the exact deterministic matrix position.
0500. M022 encodes cleanup unlink fails after committed decision.
0501. M022 invokes the unchanged production authority.
0502. M022 uses one fresh root and fixed fixture data.
0503. M022 confines mutations below the case root.
0504. M022 expected call result is commit YES; error nil; cleanupWarning nonnil.
0505. M022 expected public state is committed=YES; rollbackPerformed=NO.
0506. M022 expected filesystem state is COMMITTED_CLEANUP_WARNING; installed data intact.
0507. M022 rejects false committed completion.
0508. M022 rejects false rollback completion.
0509. M022 rejects unapproved MIXED state.
0510. M022 asserts privacy separately from code matching.
0511. M022 asserts lock and descriptor hygiene.
0512. M022 uses deterministic failure ordering.
0513. M022 accepts no field prefix or alternate field.
0514. M022 does not patch production to pass.
0515. M022 runtime result remains PENDING GitHub Actions.
0516. M022 generated artifacts remain outside Git.
0517. M022 exact domain is PXMainDataRestoreTransactionErrorDomain.
0518. M022 exact code is 11 (CleanupFailed).
0519. M022 exact field is $.transaction.cleanup.
0520. M022 uses field key PXMainDataRestoreTransactionErrorFieldPathKey.
0521. M023 occurs at the exact deterministic matrix position.
0522. M023 encodes crash after durable prepared phase.
0523. M023 invokes the unchanged production authority.
0524. M023 uses one fresh root and fixed fixture data.
0525. M023 confines mutations below the case root.
0526. M023 expected call result is child SIGKILL; fresh production-factory recovery succeeds.
0527. M023 expected public state is recoveredStaleTransactionCount=1.
0528. M023 expected filesystem state is ORIGINAL restored; workspace cleaned.
0529. M023 rejects false committed completion.
0530. M023 rejects false rollback completion.
0531. M023 rejects unapproved MIXED state.
0532. M023 asserts privacy separately from code matching.
0533. M023 asserts lock and descriptor hygiene.
0534. M023 uses deterministic failure ordering.
0535. M023 accepts no field prefix or alternate field.
0536. M023 does not patch production to pass.
0537. M023 runtime result remains PENDING GitHub Actions.
0538. M023 generated artifacts remain outside Git.
0539. M023 expects no ordinary NSError contract.
0540. M023 accepts no any-error match.
0541. M023 accepts no fallback error category.
0542. M023 retains exact success or crash/recovery assertions.
0543. M023 child must terminate by SIGKILL.
0544. M023 durable phase before recovery is prepared.
0545. M023 recovery runs in a fresh process.
0546. M023 recovered count is exactly one.
0547. M023 parent validates both child statuses.
0548. M023 recovery evidence follows the durable phase.
0549. M024 occurs at the exact deterministic matrix position.
0550. M024 encodes crash after first quarantine rename before phase publication.
0551. M024 invokes the unchanged production authority.
0552. M024 uses one fresh root and fixed fixture data.
0553. M024 confines mutations below the case root.
0554. M024 expected call result is child SIGKILL; fresh production-factory recovery succeeds.
0555. M024 expected public state is recoveredStaleTransactionCount=1.
0556. M024 expected filesystem state is ORIGINAL restored; workspace cleaned.
0557. M024 rejects false committed completion.
0558. M024 rejects false rollback completion.
0559. M024 rejects unapproved MIXED state.
0560. M024 asserts privacy separately from code matching.
0561. M024 asserts lock and descriptor hygiene.
0562. M024 uses deterministic failure ordering.
0563. M024 accepts no field prefix or alternate field.
0564. M024 does not patch production to pass.
0565. M024 runtime result remains PENDING GitHub Actions.
0566. M024 generated artifacts remain outside Git.
0567. M024 expects no ordinary NSError contract.
0568. M024 accepts no any-error match.
0569. M024 accepts no fallback error category.
0570. M024 retains exact success or crash/recovery assertions.
0571. M024 child must terminate by SIGKILL.
0572. M024 durable phase before recovery is prepared.
0573. M024 recovery runs in a fresh process.
0574. M024 recovered count is exactly one.
0575. M024 parent validates both child statuses.
0576. M024 recovery evidence follows the durable phase.
0577. M025 occurs at the exact deterministic matrix position.
0578. M025 encodes crash after durable quarantined phase.
0579. M025 invokes the unchanged production authority.
0580. M025 uses one fresh root and fixed fixture data.
0581. M025 confines mutations below the case root.
0582. M025 expected call result is child SIGKILL; fresh production-factory recovery succeeds.
0583. M025 expected public state is recoveredStaleTransactionCount=1.
0584. M025 expected filesystem state is ORIGINAL restored; workspace cleaned.
0585. M025 rejects false committed completion.
0586. M025 rejects false rollback completion.
0587. M025 rejects unapproved MIXED state.
0588. M025 asserts privacy separately from code matching.
0589. M025 asserts lock and descriptor hygiene.
0590. M025 uses deterministic failure ordering.
0591. M025 accepts no field prefix or alternate field.
0592. M025 does not patch production to pass.
0593. M025 runtime result remains PENDING GitHub Actions.
0594. M025 generated artifacts remain outside Git.
0595. M025 expects no ordinary NSError contract.
0596. M025 accepts no any-error match.
0597. M025 accepts no fallback error category.
0598. M025 retains exact success or crash/recovery assertions.
0599. M025 child must terminate by SIGKILL.
0600. M025 durable phase before recovery is quarantined.
0601. M025 recovery runs in a fresh process.
0602. M025 recovered count is exactly one.
0603. M025 parent validates both child statuses.
0604. M025 recovery evidence follows the durable phase.
0605. M026 occurs at the exact deterministic matrix position.
0606. M026 encodes crash after first install rename before installed publication.
0607. M026 invokes the unchanged production authority.
0608. M026 uses one fresh root and fixed fixture data.
0609. M026 confines mutations below the case root.
0610. M026 expected call result is child SIGKILL; fresh production-factory recovery succeeds.
0611. M026 expected public state is recoveredStaleTransactionCount=1.
0612. M026 expected filesystem state is ORIGINAL restored; workspace cleaned.
0613. M026 rejects false committed completion.
0614. M026 rejects false rollback completion.
0615. M026 rejects unapproved MIXED state.
0616. M026 asserts privacy separately from code matching.
0617. M026 asserts lock and descriptor hygiene.
0618. M026 uses deterministic failure ordering.
0619. M026 accepts no field prefix or alternate field.
0620. M026 does not patch production to pass.
0621. M026 runtime result remains PENDING GitHub Actions.
0622. M026 generated artifacts remain outside Git.
0623. M026 expects no ordinary NSError contract.
0624. M026 accepts no any-error match.
0625. M026 accepts no fallback error category.
0626. M026 retains exact success or crash/recovery assertions.
0627. M026 child must terminate by SIGKILL.
0628. M026 durable phase before recovery is quarantined.
0629. M026 recovery runs in a fresh process.
0630. M026 recovered count is exactly one.
0631. M026 parent validates both child statuses.
0632. M026 recovery evidence follows the durable phase.
0633. M027 occurs at the exact deterministic matrix position.
0634. M027 encodes crash after durable installed phase.
0635. M027 invokes the unchanged production authority.
0636. M027 uses one fresh root and fixed fixture data.
0637. M027 confines mutations below the case root.
0638. M027 expected call result is child SIGKILL; fresh production-factory recovery succeeds.
0639. M027 expected public state is recoveredStaleTransactionCount=1.
0640. M027 expected filesystem state is ORIGINAL restored; workspace cleaned.
0641. M027 rejects false committed completion.
0642. M027 rejects false rollback completion.
0643. M027 rejects unapproved MIXED state.
0644. M027 asserts privacy separately from code matching.
0645. M027 asserts lock and descriptor hygiene.
0646. M027 uses deterministic failure ordering.
0647. M027 accepts no field prefix or alternate field.
0648. M027 does not patch production to pass.
0649. M027 runtime result remains PENDING GitHub Actions.
0650. M027 generated artifacts remain outside Git.
0651. M027 expects no ordinary NSError contract.
0652. M027 accepts no any-error match.
0653. M027 accepts no fallback error category.
0654. M027 retains exact success or crash/recovery assertions.
0655. M027 child must terminate by SIGKILL.
0656. M027 durable phase before recovery is installed.
0657. M027 recovery runs in a fresh process.
0658. M027 recovered count is exactly one.
0659. M027 parent validates both child statuses.
0660. M027 recovery evidence follows the durable phase.
0661. M028 occurs at the exact deterministic matrix position.
0662. M028 encodes crash after durable committed phase.
0663. M028 invokes the unchanged production authority.
0664. M028 uses one fresh root and fixed fixture data.
0665. M028 confines mutations below the case root.
0666. M028 expected call result is child SIGKILL; fresh production-factory recovery succeeds.
0667. M028 expected public state is recoveredStaleTransactionCount=1.
0668. M028 expected filesystem state is INSTALLED preserved; workspace cleaned.
0669. M028 rejects false committed completion.
0670. M028 rejects false rollback completion.
0671. M028 rejects unapproved MIXED state.
0672. M028 asserts privacy separately from code matching.
0673. M028 asserts lock and descriptor hygiene.
0674. M028 uses deterministic failure ordering.
0675. M028 accepts no field prefix or alternate field.
0676. M028 does not patch production to pass.
0677. M028 runtime result remains PENDING GitHub Actions.
0678. M028 generated artifacts remain outside Git.
0679. M028 expects no ordinary NSError contract.
0680. M028 accepts no any-error match.
0681. M028 accepts no fallback error category.
0682. M028 retains exact success or crash/recovery assertions.
0683. M028 child must terminate by SIGKILL.
0684. M028 durable phase before recovery is committed.
0685. M028 recovery runs in a fresh process.
0686. M028 recovered count is exactly one.
0687. M028 parent validates both child statuses.
0688. M028 recovery evidence follows the durable phase.
0689. M029 occurs at the exact deterministic matrix position.
0690. M029 encodes crash after durable rolling-back phase.
0691. M029 invokes the unchanged production authority.
0692. M029 uses one fresh root and fixed fixture data.
0693. M029 confines mutations below the case root.
0694. M029 expected call result is child SIGKILL; fresh production-factory recovery succeeds.
0695. M029 expected public state is recoveredStaleTransactionCount=1.
0696. M029 expected filesystem state is ORIGINAL restored; workspace cleaned.
0697. M029 rejects false committed completion.
0698. M029 rejects false rollback completion.
0699. M029 rejects unapproved MIXED state.
0700. M029 asserts privacy separately from code matching.
0701. M029 asserts lock and descriptor hygiene.
0702. M029 uses deterministic failure ordering.
0703. M029 accepts no field prefix or alternate field.
0704. M029 does not patch production to pass.
0705. M029 runtime result remains PENDING GitHub Actions.
0706. M029 generated artifacts remain outside Git.
0707. M029 expects no ordinary NSError contract.
0708. M029 accepts no any-error match.
0709. M029 accepts no fallback error category.
0710. M029 retains exact success or crash/recovery assertions.
0711. M029 child must terminate by SIGKILL.
0712. M029 durable phase before recovery is rolling-back.
0713. M029 recovery runs in a fresh process.
0714. M029 recovered count is exactly one.
0715. M029 parent validates both child statuses.
0716. M029 recovery evidence follows the durable phase.
0717. M030 occurs at the exact deterministic matrix position.
0718. M030 encodes crash after durable rolled-back phase.
0719. M030 invokes the unchanged production authority.
0720. M030 uses one fresh root and fixed fixture data.
0721. M030 confines mutations below the case root.
0722. M030 expected call result is child SIGKILL; fresh production-factory recovery succeeds.
0723. M030 expected public state is recoveredStaleTransactionCount=1.
0724. M030 expected filesystem state is ORIGINAL restored; workspace cleaned.
0725. M030 rejects false committed completion.
0726. M030 rejects false rollback completion.
0727. M030 rejects unapproved MIXED state.
0728. M030 asserts privacy separately from code matching.
0729. M030 asserts lock and descriptor hygiene.
0730. M030 uses deterministic failure ordering.
0731. M030 accepts no field prefix or alternate field.
0732. M030 does not patch production to pass.
0733. M030 runtime result remains PENDING GitHub Actions.
0734. M030 generated artifacts remain outside Git.
0735. M030 expects no ordinary NSError contract.
0736. M030 accepts no any-error match.
0737. M030 accepts no fallback error category.
0738. M030 retains exact success or crash/recovery assertions.
0739. M030 child must terminate by SIGKILL.
0740. M030 durable phase before recovery is rolled-back.
0741. M030 recovery runs in a fresh process.
0742. M030 recovered count is exactly one.
0743. M030 parent validates both child statuses.
0744. M030 recovery evidence follows the durable phase.
0745. G001 occurs at the exact deterministic matrix position.
0746. G001 encodes clean two-target batch commit.
0747. G001 invokes the unchanged production authority.
0748. G001 uses one fresh root and fixed fixture data.
0749. G001 confines mutations below the case root.
0750. G001 expected call result is commit YES; error nil; cleanupWarning nil.
0751. G001 expected public state is committed=YES; rollbackPerformed=NO; rollbackComplete=NO; targetCount=2; recovered=0.
0752. G001 expected filesystem state is both targets INSTALLED; no mixed target; no workspace.
0753. G001 rejects false committed completion.
0754. G001 rejects false rollback completion.
0755. G001 rejects unapproved MIXED state.
0756. G001 asserts privacy separately from code matching.
0757. G001 asserts lock and descriptor hygiene.
0758. G001 uses deterministic failure ordering.
0759. G001 accepts no field prefix or alternate field.
0760. G001 does not patch production to pass.
0761. G001 runtime result remains PENDING GitHub Actions.
0762. G001 generated artifacts remain outside Git.
0763. G001 expects no ordinary NSError contract.
0764. G001 accepts no any-error match.
0765. G001 accepts no fallback error category.
0766. G001 retains exact success or crash/recovery assertions.
0767. G002 occurs at the exact deterministic matrix position.
0768. G002 encodes second commit.
0769. G002 invokes the unchanged production authority.
0770. G002 uses one fresh root and fixed fixture data.
0771. G002 confines mutations below the case root.
0772. G002 expected call result is second commit NO.
0773. G002 expected public state is committed remains YES.
0774. G002 expected filesystem state is both targets INSTALLED unchanged.
0775. G002 rejects false committed completion.
0776. G002 rejects false rollback completion.
0777. G002 rejects unapproved MIXED state.
0778. G002 asserts privacy separately from code matching.
0779. G002 asserts lock and descriptor hygiene.
0780. G002 uses deterministic failure ordering.
0781. G002 accepts no field prefix or alternate field.
0782. G002 does not patch production to pass.
0783. G002 runtime result remains PENDING GitHub Actions.
0784. G002 generated artifacts remain outside Git.
0785. G002 exact domain is PXAppGroupRestoreTransactionErrorDomain.
0786. G002 exact code is 1 (InvalidInput).
0787. G002 exact field is $.
0788. G002 uses field key PXAppGroupRestoreTransactionErrorFieldPathKey.
0789. G003 occurs at the exact deterministic matrix position.
0790. G003 encodes real lock contention on first target.
0791. G003 invokes the unchanged production authority.
0792. G003 uses one fresh root and fixed fixture data.
0793. G003 confines mutations below the case root.
0794. G003 expected call result is factory nil.
0795. G003 expected public state is no transaction object.
0796. G003 expected filesystem state is both targets ORIGINAL; locks released.
0797. G003 rejects false committed completion.
0798. G003 rejects false rollback completion.
0799. G003 rejects unapproved MIXED state.
0800. G003 asserts privacy separately from code matching.
0801. G003 asserts lock and descriptor hygiene.
0802. G003 uses deterministic failure ordering.
0803. G003 accepts no field prefix or alternate field.
0804. G003 does not patch production to pass.
0805. G003 runtime result remains PENDING GitHub Actions.
0806. G003 generated artifacts remain outside Git.
0807. G003 exact domain is PXAppGroupRestoreTransactionErrorDomain.
0808. G003 exact code is 4 (LockFailed).
0809. G003 exact field is $.locks.
0810. G003 uses field key PXAppGroupRestoreTransactionErrorFieldPathKey.
0811. G004 occurs at the exact deterministic matrix position.
0812. G004 encodes real lock contention on second target.
0813. G004 invokes the unchanged production authority.
0814. G004 uses one fresh root and fixed fixture data.
0815. G004 confines mutations below the case root.
0816. G004 expected call result is factory nil.
0817. G004 expected public state is no transaction object.
0818. G004 expected filesystem state is both targets ORIGINAL; locks released.
0819. G004 rejects false committed completion.
0820. G004 rejects false rollback completion.
0821. G004 rejects unapproved MIXED state.
0822. G004 asserts privacy separately from code matching.
0823. G004 asserts lock and descriptor hygiene.
0824. G004 uses deterministic failure ordering.
0825. G004 accepts no field prefix or alternate field.
0826. G004 does not patch production to pass.
0827. G004 runtime result remains PENDING GitHub Actions.
0828. G004 generated artifacts remain outside Git.
0829. G004 exact domain is PXAppGroupRestoreTransactionErrorDomain.
0830. G004 exact code is 4 (LockFailed).
0831. G004 exact field is $.locks.
0832. G004 uses field key PXAppGroupRestoreTransactionErrorFieldPathKey.
0833. G005 occurs at the exact deterministic matrix position.
0834. G005 encodes mutate second stage st_dev.
0835. G005 invokes the unchanged production authority.
0836. G005 uses one fresh root and fixed fixture data.
0837. G005 confines mutations below the case root.
0838. G005 expected call result is factory nil.
0839. G005 expected public state is no transaction object.
0840. G005 expected filesystem state is both targets ORIGINAL.
0841. G005 rejects false committed completion.
0842. G005 rejects false rollback completion.
0843. G005 rejects unapproved MIXED state.
0844. G005 asserts privacy separately from code matching.
0845. G005 asserts lock and descriptor hygiene.
0846. G005 uses deterministic failure ordering.
0847. G005 accepts no field prefix or alternate field.
0848. G005 does not patch production to pass.
0849. G005 runtime result remains PENDING GitHub Actions.
0850. G005 generated artifacts remain outside Git.
0851. G005 exact domain is PXAppGroupRestoreTransactionErrorDomain.
0852. G005 exact code is 5 (CrossDeviceBoundary).
0853. G005 exact field is $.stage.
0854. G005 uses field key PXAppGroupRestoreTransactionErrorFieldPathKey.
0855. G006 occurs at the exact deterministic matrix position.
0856. G006 encodes one EINTR on leader prepared-journal write.
0857. G006 invokes the unchanged production authority.
0858. G006 uses one fresh root and fixed fixture data.
0859. G006 confines mutations below the case root.
0860. G006 expected call result is commit YES; error nil; cleanupWarning nil.
0861. G006 expected public state is committed=YES; rollbackPerformed=NO; rollbackComplete=NO; targetCount=2; recovered=0.
0862. G006 expected filesystem state is both targets INSTALLED; no mixed target; no workspace.
0863. G006 rejects false committed completion.
0864. G006 rejects false rollback completion.
0865. G006 rejects unapproved MIXED state.
0866. G006 asserts privacy separately from code matching.
0867. G006 asserts lock and descriptor hygiene.
0868. G006 uses deterministic failure ordering.
0869. G006 accepts no field prefix or alternate field.
0870. G006 does not patch production to pass.
0871. G006 runtime result remains PENDING GitHub Actions.
0872. G006 generated artifacts remain outside Git.
0873. G006 expects no ordinary NSError contract.
0874. G006 accepts no any-error match.
0875. G006 accepts no fallback error category.
0876. G006 retains exact success or crash/recovery assertions.
0877. G007 occurs at the exact deterministic matrix position.
0878. G007 encodes second participant workspace mkdirat fails ENOSPC.
0879. G007 invokes the unchanged production authority.
0880. G007 uses one fresh root and fixed fixture data.
0881. G007 confines mutations below the case root.
0882. G007 expected call result is commit NO.
0883. G007 expected public state is committed=NO; rollbackPerformed=NO; rollbackComplete=NO.
0884. G007 expected filesystem state is both targets ORIGINAL; temporary workspaces cleaned.
0885. G007 rejects false committed completion.
0886. G007 rejects false rollback completion.
0887. G007 rejects unapproved MIXED state.
0888. G007 asserts privacy separately from code matching.
0889. G007 asserts lock and descriptor hygiene.
0890. G007 uses deterministic failure ordering.
0891. G007 accepts no field prefix or alternate field.
0892. G007 does not patch production to pass.
0893. G007 runtime result remains PENDING GitHub Actions.
0894. G007 generated artifacts remain outside Git.
0895. G007 exact domain is PXAppGroupRestoreTransactionErrorDomain.
0896. G007 exact code is 7 (JournalCreationFailed).
0897. G007 exact field is $.journal.
0898. G007 uses field key PXAppGroupRestoreTransactionErrorFieldPathKey.
0899. G008 occurs at the exact deterministic matrix position.
0900. G008 encodes workspace/target preparation sync fails.
0901. G008 invokes the unchanged production authority.
0902. G008 uses one fresh root and fixed fixture data.
0903. G008 confines mutations below the case root.
0904. G008 expected call result is commit NO.
0905. G008 expected public state is committed=NO; rollbackPerformed=NO; rollbackComplete=NO.
0906. G008 expected filesystem state is both targets ORIGINAL; temporary workspaces cleaned.
0907. G008 rejects false committed completion.
0908. G008 rejects false rollback completion.
0909. G008 rejects unapproved MIXED state.
0910. G008 asserts privacy separately from code matching.
0911. G008 asserts lock and descriptor hygiene.
0912. G008 uses deterministic failure ordering.
0913. G008 accepts no field prefix or alternate field.
0914. G008 does not patch production to pass.
0915. G008 runtime result remains PENDING GitHub Actions.
0916. G008 generated artifacts remain outside Git.
0917. G008 exact domain is PXAppGroupRestoreTransactionErrorDomain.
0918. G008 exact code is 7 (JournalCreationFailed).
0919. G008 exact field is $.journal.
0920. G008 uses field key PXAppGroupRestoreTransactionErrorFieldPathKey.
0921. G009 occurs at the exact deterministic matrix position.
0922. G009 encodes prepared leader-journal write fails ENOSPC.
0923. G009 invokes the unchanged production authority.
0924. G009 uses one fresh root and fixed fixture data.
0925. G009 confines mutations below the case root.
0926. G009 expected call result is commit NO.
0927. G009 expected public state is committed=NO; rollbackPerformed=NO; rollbackComplete=NO.
0928. G009 expected filesystem state is both targets ORIGINAL; temporary workspaces cleaned.
0929. G009 rejects false committed completion.
0930. G009 rejects false rollback completion.
0931. G009 rejects unapproved MIXED state.
0932. G009 asserts privacy separately from code matching.
0933. G009 asserts lock and descriptor hygiene.
0934. G009 uses deterministic failure ordering.
0935. G009 accepts no field prefix or alternate field.
0936. G009 does not patch production to pass.
0937. G009 runtime result remains PENDING GitHub Actions.
0938. G009 generated artifacts remain outside Git.
0939. G009 exact domain is PXAppGroupRestoreTransactionErrorDomain.
0940. G009 exact code is 7 (JournalCreationFailed).
0941. G009 exact field is $.journal.
0942. G009 uses field key PXAppGroupRestoreTransactionErrorFieldPathKey.
0943. G010 occurs at the exact deterministic matrix position.
0944. G010 encodes prepared leader-journal publication fails.
0945. G010 invokes the unchanged production authority.
0946. G010 uses one fresh root and fixed fixture data.
0947. G010 confines mutations below the case root.
0948. G010 expected call result is commit NO.
0949. G010 expected public state is committed=NO; rollbackPerformed=NO; rollbackComplete=NO.
0950. G010 expected filesystem state is both targets ORIGINAL; temporary workspaces cleaned.
0951. G010 rejects false committed completion.
0952. G010 rejects false rollback completion.
0953. G010 rejects unapproved MIXED state.
0954. G010 asserts privacy separately from code matching.
0955. G010 asserts lock and descriptor hygiene.
0956. G010 uses deterministic failure ordering.
0957. G010 accepts no field prefix or alternate field.
0958. G010 does not patch production to pass.
0959. G010 runtime result remains PENDING GitHub Actions.
0960. G010 generated artifacts remain outside Git.
0961. G010 exact domain is PXAppGroupRestoreTransactionErrorDomain.
0962. G010 exact code is 7 (JournalCreationFailed).
0963. G010 exact field is $.journal.
0964. G010 uses field key PXAppGroupRestoreTransactionErrorFieldPathKey.
0965. G011 occurs at the exact deterministic matrix position.
0966. G011 encodes first target quarantine rename fails.
0967. G011 invokes the unchanged production authority.
0968. G011 uses one fresh root and fixed fixture data.
0969. G011 confines mutations below the case root.
0970. G011 expected call result is commit NO.
0971. G011 expected public state is committed=NO; rollbackPerformed=YES; rollbackComplete=YES.
0972. G011 expected filesystem state is whole batch ORIGINAL; no mixed target; workspace cleaned.
0973. G011 rejects false committed completion.
0974. G011 rejects false rollback completion.
0975. G011 rejects unapproved MIXED state.
0976. G011 asserts privacy separately from code matching.
0977. G011 asserts lock and descriptor hygiene.
0978. G011 uses deterministic failure ordering.
0979. G011 accepts no field prefix or alternate field.
0980. G011 does not patch production to pass.
0981. G011 runtime result remains PENDING GitHub Actions.
0982. G011 generated artifacts remain outside Git.
0983. G011 exact domain is PXAppGroupRestoreTransactionErrorDomain.
0984. G011 exact code is 9 (QuarantineFailed).
0985. G011 exact field is $.transaction.quarantine.
0986. G011 uses field key PXAppGroupRestoreTransactionErrorFieldPathKey.
0987. G012 occurs at the exact deterministic matrix position.
0988. G012 encodes second target quarantine rename fails.
0989. G012 invokes the unchanged production authority.
0990. G012 uses one fresh root and fixed fixture data.
0991. G012 confines mutations below the case root.
0992. G012 expected call result is commit NO.
0993. G012 expected public state is committed=NO; rollbackPerformed=YES; rollbackComplete=YES.
0994. G012 expected filesystem state is whole batch ORIGINAL; no mixed target; workspace cleaned.
0995. G012 rejects false committed completion.
0996. G012 rejects false rollback completion.
0997. G012 rejects unapproved MIXED state.
0998. G012 asserts privacy separately from code matching.
0999. G012 asserts lock and descriptor hygiene.
1000. G012 uses deterministic failure ordering.
1001. G012 accepts no field prefix or alternate field.
1002. G012 does not patch production to pass.
1003. G012 runtime result remains PENDING GitHub Actions.
1004. G012 generated artifacts remain outside Git.
1005. G012 exact domain is PXAppGroupRestoreTransactionErrorDomain.
1006. G012 exact code is 9 (QuarantineFailed).
1007. G012 exact field is $.transaction.quarantine.
1008. G012 uses field key PXAppGroupRestoreTransactionErrorFieldPathKey.
1009. G013 occurs at the exact deterministic matrix position.
1010. G013 encodes quarantine sync fails.
1011. G013 invokes the unchanged production authority.
1012. G013 uses one fresh root and fixed fixture data.
1013. G013 confines mutations below the case root.
1014. G013 expected call result is commit NO.
1015. G013 expected public state is committed=NO; rollbackPerformed=YES; rollbackComplete=YES.
1016. G013 expected filesystem state is whole batch ORIGINAL; no mixed target; workspace cleaned.
1017. G013 rejects false committed completion.
1018. G013 rejects false rollback completion.
1019. G013 rejects unapproved MIXED state.
1020. G013 asserts privacy separately from code matching.
1021. G013 asserts lock and descriptor hygiene.
1022. G013 uses deterministic failure ordering.
1023. G013 accepts no field prefix or alternate field.
1024. G013 does not patch production to pass.
1025. G013 runtime result remains PENDING GitHub Actions.
1026. G013 generated artifacts remain outside Git.
1027. G013 exact domain is PXAppGroupRestoreTransactionErrorDomain.
1028. G013 exact code is 9 (QuarantineFailed).
1029. G013 exact field is $.transaction.quarantine.
1030. G013 uses field key PXAppGroupRestoreTransactionErrorFieldPathKey.
1031. G014 occurs at the exact deterministic matrix position.
1032. G014 encodes quarantined leader-journal publication fails.
1033. G014 invokes the unchanged production authority.
1034. G014 uses one fresh root and fixed fixture data.
1035. G014 confines mutations below the case root.
1036. G014 expected call result is commit NO.
1037. G014 expected public state is committed=NO; rollbackPerformed=YES; rollbackComplete=YES.
1038. G014 expected filesystem state is whole batch ORIGINAL; no mixed target; workspace cleaned.
1039. G014 rejects false committed completion.
1040. G014 rejects false rollback completion.
1041. G014 rejects unapproved MIXED state.
1042. G014 asserts privacy separately from code matching.
1043. G014 asserts lock and descriptor hygiene.
1044. G014 uses deterministic failure ordering.
1045. G014 accepts no field prefix or alternate field.
1046. G014 does not patch production to pass.
1047. G014 runtime result remains PENDING GitHub Actions.
1048. G014 generated artifacts remain outside Git.
1049. G014 exact domain is PXAppGroupRestoreTransactionErrorDomain.
1050. G014 exact code is 9 (QuarantineFailed).
1051. G014 exact field is $.transaction.quarantine.
1052. G014 uses field key PXAppGroupRestoreTransactionErrorFieldPathKey.
1053. G015 occurs at the exact deterministic matrix position.
1054. G015 encodes first target install rename fails.
1055. G015 invokes the unchanged production authority.
1056. G015 uses one fresh root and fixed fixture data.
1057. G015 confines mutations below the case root.
1058. G015 expected call result is commit NO.
1059. G015 expected public state is committed=NO; rollbackPerformed=YES; rollbackComplete=YES.
1060. G015 expected filesystem state is whole batch ORIGINAL; no mixed target; workspace cleaned.
1061. G015 rejects false committed completion.
1062. G015 rejects false rollback completion.
1063. G015 rejects unapproved MIXED state.
1064. G015 asserts privacy separately from code matching.
1065. G015 asserts lock and descriptor hygiene.
1066. G015 uses deterministic failure ordering.
1067. G015 accepts no field prefix or alternate field.
1068. G015 does not patch production to pass.
1069. G015 runtime result remains PENDING GitHub Actions.
1070. G015 generated artifacts remain outside Git.
1071. G015 exact domain is PXAppGroupRestoreTransactionErrorDomain.
1072. G015 exact code is 10 (CommitFailed).
1073. G015 exact field is $.transaction.commit.
1074. G015 uses field key PXAppGroupRestoreTransactionErrorFieldPathKey.
1075. G016 occurs at the exact deterministic matrix position.
1076. G016 encodes second target install rename fails.
1077. G016 invokes the unchanged production authority.
1078. G016 uses one fresh root and fixed fixture data.
1079. G016 confines mutations below the case root.
1080. G016 expected call result is commit NO.
1081. G016 expected public state is committed=NO; rollbackPerformed=YES; rollbackComplete=YES.
1082. G016 expected filesystem state is whole batch ORIGINAL; no mixed target; workspace cleaned.
1083. G016 rejects false committed completion.
1084. G016 rejects false rollback completion.
1085. G016 rejects unapproved MIXED state.
1086. G016 asserts privacy separately from code matching.
1087. G016 asserts lock and descriptor hygiene.
1088. G016 uses deterministic failure ordering.
1089. G016 accepts no field prefix or alternate field.
1090. G016 does not patch production to pass.
1091. G016 runtime result remains PENDING GitHub Actions.
1092. G016 generated artifacts remain outside Git.
1093. G016 exact domain is PXAppGroupRestoreTransactionErrorDomain.
1094. G016 exact code is 10 (CommitFailed).
1095. G016 exact field is $.transaction.commit.
1096. G016 uses field key PXAppGroupRestoreTransactionErrorFieldPathKey.
1097. G017 occurs at the exact deterministic matrix position.
1098. G017 encodes install sync fails.
1099. G017 invokes the unchanged production authority.
1100. G017 uses one fresh root and fixed fixture data.
1101. G017 confines mutations below the case root.
1102. G017 expected call result is commit NO.
1103. G017 expected public state is committed=NO; rollbackPerformed=YES; rollbackComplete=YES.
1104. G017 expected filesystem state is whole batch ORIGINAL; no mixed target; workspace cleaned.
1105. G017 rejects false committed completion.
1106. G017 rejects false rollback completion.
1107. G017 rejects unapproved MIXED state.
1108. G017 asserts privacy separately from code matching.
1109. G017 asserts lock and descriptor hygiene.
1110. G017 uses deterministic failure ordering.
1111. G017 accepts no field prefix or alternate field.
1112. G017 does not patch production to pass.
1113. G017 runtime result remains PENDING GitHub Actions.
1114. G017 generated artifacts remain outside Git.
1115. G017 exact domain is PXAppGroupRestoreTransactionErrorDomain.
1116. G017 exact code is 10 (CommitFailed).
1117. G017 exact field is $.transaction.commit.
1118. G017 uses field key PXAppGroupRestoreTransactionErrorFieldPathKey.
1119. G018 occurs at the exact deterministic matrix position.
1120. G018 encodes installed leader-journal publication fails.
1121. G018 invokes the unchanged production authority.
1122. G018 uses one fresh root and fixed fixture data.
1123. G018 confines mutations below the case root.
1124. G018 expected call result is commit NO.
1125. G018 expected public state is committed=NO; rollbackPerformed=YES; rollbackComplete=YES.
1126. G018 expected filesystem state is whole batch ORIGINAL; no mixed target; workspace cleaned.
1127. G018 rejects false committed completion.
1128. G018 rejects false rollback completion.
1129. G018 rejects unapproved MIXED state.
1130. G018 asserts privacy separately from code matching.
1131. G018 asserts lock and descriptor hygiene.
1132. G018 uses deterministic failure ordering.
1133. G018 accepts no field prefix or alternate field.
1134. G018 does not patch production to pass.
1135. G018 runtime result remains PENDING GitHub Actions.
1136. G018 generated artifacts remain outside Git.
1137. G018 exact domain is PXAppGroupRestoreTransactionErrorDomain.
1138. G018 exact code is 10 (CommitFailed).
1139. G018 exact field is $.transaction.commit.
1140. G018 uses field key PXAppGroupRestoreTransactionErrorFieldPathKey.
1141. G019 occurs at the exact deterministic matrix position.
1142. G019 encodes committed leader-journal publication fails.
1143. G019 invokes the unchanged production authority.
1144. G019 uses one fresh root and fixed fixture data.
1145. G019 confines mutations below the case root.
1146. G019 expected call result is commit NO.
1147. G019 expected public state is committed=NO; rollbackPerformed=YES; rollbackComplete=YES.
1148. G019 expected filesystem state is whole batch ORIGINAL; no mixed target; workspace cleaned.
1149. G019 rejects false committed completion.
1150. G019 rejects false rollback completion.
1151. G019 rejects unapproved MIXED state.
1152. G019 asserts privacy separately from code matching.
1153. G019 asserts lock and descriptor hygiene.
1154. G019 uses deterministic failure ordering.
1155. G019 accepts no field prefix or alternate field.
1156. G019 does not patch production to pass.
1157. G019 runtime result remains PENDING GitHub Actions.
1158. G019 generated artifacts remain outside Git.
1159. G019 exact domain is PXAppGroupRestoreTransactionErrorDomain.
1160. G019 exact code is 10 (CommitFailed).
1161. G019 exact field is $.transaction.commit.
1162. G019 uses field key PXAppGroupRestoreTransactionErrorFieldPathKey.
1163. G020 occurs at the exact deterministic matrix position.
1164. G020 encodes rollback installed-to-new rename fails.
1165. G020 invokes the unchanged production authority.
1166. G020 uses one fresh root and fixed fixture data.
1167. G020 confines mutations below the case root.
1168. G020 expected call result is commit NO.
1169. G020 expected public state is committed=NO; rollbackPerformed=YES; rollbackComplete=NO.
1170. G020 expected filesystem state is ROLLBACK_EVIDENCE retained; batch not falsely committed.
1171. G020 rejects false committed completion.
1172. G020 rejects false rollback completion.
1173. G020 rejects unapproved MIXED state.
1174. G020 asserts privacy separately from code matching.
1175. G020 asserts lock and descriptor hygiene.
1176. G020 uses deterministic failure ordering.
1177. G020 accepts no field prefix or alternate field.
1178. G020 does not patch production to pass.
1179. G020 runtime result remains PENDING GitHub Actions.
1180. G020 generated artifacts remain outside Git.
1181. G020 exact domain is PXAppGroupRestoreTransactionErrorDomain.
1182. G020 exact code is 11 (RollbackFailed).
1183. G020 exact field is $.transaction.rollback.
1184. G020 uses field key PXAppGroupRestoreTransactionErrorFieldPathKey.
1185. G021 occurs at the exact deterministic matrix position.
1186. G021 encodes rollback original restore fails.
1187. G021 invokes the unchanged production authority.
1188. G021 uses one fresh root and fixed fixture data.
1189. G021 confines mutations below the case root.
1190. G021 expected call result is commit NO.
1191. G021 expected public state is committed=NO; rollbackPerformed=YES; rollbackComplete=NO.
1192. G021 expected filesystem state is ROLLBACK_EVIDENCE retained; batch not falsely committed.
1193. G021 rejects false committed completion.
1194. G021 rejects false rollback completion.
1195. G021 rejects unapproved MIXED state.
1196. G021 asserts privacy separately from code matching.
1197. G021 asserts lock and descriptor hygiene.
1198. G021 uses deterministic failure ordering.
1199. G021 accepts no field prefix or alternate field.
1200. G021 does not patch production to pass.
1201. G021 runtime result remains PENDING GitHub Actions.
1202. G021 generated artifacts remain outside Git.
1203. G021 exact domain is PXAppGroupRestoreTransactionErrorDomain.
1204. G021 exact code is 11 (RollbackFailed).
1205. G021 exact field is $.transaction.rollback.
1206. G021 uses field key PXAppGroupRestoreTransactionErrorFieldPathKey.
1207. G022 occurs at the exact deterministic matrix position.
1208. G022 encodes rolled-back leader-journal publication fails.
1209. G022 invokes the unchanged production authority.
1210. G022 uses one fresh root and fixed fixture data.
1211. G022 confines mutations below the case root.
1212. G022 expected call result is commit NO.
1213. G022 expected public state is committed=NO; rollbackPerformed=YES; rollbackComplete=NO.
1214. G022 expected filesystem state is ROLLBACK_EVIDENCE retained; batch not falsely committed.
1215. G022 rejects false committed completion.
1216. G022 rejects false rollback completion.
1217. G022 rejects unapproved MIXED state.
1218. G022 asserts privacy separately from code matching.
1219. G022 asserts lock and descriptor hygiene.
1220. G022 uses deterministic failure ordering.
1221. G022 accepts no field prefix or alternate field.
1222. G022 does not patch production to pass.
1223. G022 runtime result remains PENDING GitHub Actions.
1224. G022 generated artifacts remain outside Git.
1225. G022 exact domain is PXAppGroupRestoreTransactionErrorDomain.
1226. G022 exact code is 11 (RollbackFailed).
1227. G022 exact field is $.transaction.rollback.
1228. G022 uses field key PXAppGroupRestoreTransactionErrorFieldPathKey.
1229. G023 occurs at the exact deterministic matrix position.
1230. G023 encodes nonleader cleanup unlink fails after commit.
1231. G023 invokes the unchanged production authority.
1232. G023 uses one fresh root and fixed fixture data.
1233. G023 confines mutations below the case root.
1234. G023 expected call result is commit YES; error nil; cleanupWarning nonnil.
1235. G023 expected public state is committed=YES; rollbackPerformed=NO.
1236. G023 expected filesystem state is both targets INSTALLED; confined evidence retained.
1237. G023 rejects false committed completion.
1238. G023 rejects false rollback completion.
1239. G023 rejects unapproved MIXED state.
1240. G023 asserts privacy separately from code matching.
1241. G023 asserts lock and descriptor hygiene.
1242. G023 uses deterministic failure ordering.
1243. G023 accepts no field prefix or alternate field.
1244. G023 does not patch production to pass.
1245. G023 runtime result remains PENDING GitHub Actions.
1246. G023 generated artifacts remain outside Git.
1247. G023 exact domain is PXAppGroupRestoreTransactionErrorDomain.
1248. G023 exact code is 12 (CleanupFailed).
1249. G023 exact field is $.transaction.cleanup.
1250. G023 uses field key PXAppGroupRestoreTransactionErrorFieldPathKey.
1251. G024 occurs at the exact deterministic matrix position.
1252. G024 encodes leader cleanup fails after commit.
1253. G024 invokes the unchanged production authority.
1254. G024 uses one fresh root and fixed fixture data.
1255. G024 confines mutations below the case root.
1256. G024 expected call result is commit YES; error nil; cleanupWarning nonnil.
1257. G024 expected public state is committed=YES; rollbackPerformed=NO.
1258. G024 expected filesystem state is both targets INSTALLED; confined evidence retained.
1259. G024 rejects false committed completion.
1260. G024 rejects false rollback completion.
1261. G024 rejects unapproved MIXED state.
1262. G024 asserts privacy separately from code matching.
1263. G024 asserts lock and descriptor hygiene.
1264. G024 uses deterministic failure ordering.
1265. G024 accepts no field prefix or alternate field.
1266. G024 does not patch production to pass.
1267. G024 runtime result remains PENDING GitHub Actions.
1268. G024 generated artifacts remain outside Git.
1269. G024 exact domain is PXAppGroupRestoreTransactionErrorDomain.
1270. G024 exact code is 12 (CleanupFailed).
1271. G024 exact field is $.transaction.cleanup.
1272. G024 uses field key PXAppGroupRestoreTransactionErrorFieldPathKey.
1273. G025 occurs at the exact deterministic matrix position.
1274. G025 encodes crash after durable prepared phase.
1275. G025 invokes the unchanged production authority.
1276. G025 uses one fresh root and fixed fixture data.
1277. G025 confines mutations below the case root.
1278. G025 expected call result is child SIGKILL; fresh production-factory recovery succeeds.
1279. G025 expected public state is recoveredStaleBatchCount=1; targetCount=2.
1280. G025 expected filesystem state is both targets ORIGINAL; no mixed target; workspaces cleaned.
1281. G025 rejects false committed completion.
1282. G025 rejects false rollback completion.
1283. G025 rejects unapproved MIXED state.
1284. G025 asserts privacy separately from code matching.
1285. G025 asserts lock and descriptor hygiene.
1286. G025 uses deterministic failure ordering.
1287. G025 accepts no field prefix or alternate field.
1288. G025 does not patch production to pass.
1289. G025 runtime result remains PENDING GitHub Actions.
1290. G025 generated artifacts remain outside Git.
1291. G025 expects no ordinary NSError contract.
1292. G025 accepts no any-error match.
1293. G025 accepts no fallback error category.
1294. G025 retains exact success or crash/recovery assertions.
1295. G025 child must terminate by SIGKILL.
1296. G025 durable phase before recovery is prepared.
1297. G025 recovery runs in a fresh process.
1298. G025 recovered count is exactly one.
1299. G025 parent validates both child statuses.
1300. G025 recovery evidence follows the durable phase.
1301. G026 occurs at the exact deterministic matrix position.
1302. G026 encodes crash after partial quarantine of later target.
1303. G026 invokes the unchanged production authority.
1304. G026 uses one fresh root and fixed fixture data.
1305. G026 confines mutations below the case root.
1306. G026 expected call result is child SIGKILL; fresh production-factory recovery succeeds.
1307. G026 expected public state is recoveredStaleBatchCount=1; targetCount=2.
1308. G026 expected filesystem state is both targets ORIGINAL; no mixed target; workspaces cleaned.
1309. G026 rejects false committed completion.
1310. G026 rejects false rollback completion.
1311. G026 rejects unapproved MIXED state.
1312. G026 asserts privacy separately from code matching.
1313. G026 asserts lock and descriptor hygiene.
1314. G026 uses deterministic failure ordering.
1315. G026 accepts no field prefix or alternate field.
1316. G026 does not patch production to pass.
1317. G026 runtime result remains PENDING GitHub Actions.
1318. G026 generated artifacts remain outside Git.
1319. G026 expects no ordinary NSError contract.
1320. G026 accepts no any-error match.
1321. G026 accepts no fallback error category.
1322. G026 retains exact success or crash/recovery assertions.
1323. G026 child must terminate by SIGKILL.
1324. G026 durable phase before recovery is prepared.
1325. G026 recovery runs in a fresh process.
1326. G026 recovered count is exactly one.
1327. G026 parent validates both child statuses.
1328. G026 recovery evidence follows the durable phase.
1329. G027 occurs at the exact deterministic matrix position.
1330. G027 encodes crash after durable quarantined phase.
1331. G027 invokes the unchanged production authority.
1332. G027 uses one fresh root and fixed fixture data.
1333. G027 confines mutations below the case root.
1334. G027 expected call result is child SIGKILL; fresh production-factory recovery succeeds.
1335. G027 expected public state is recoveredStaleBatchCount=1; targetCount=2.
1336. G027 expected filesystem state is both targets ORIGINAL; no mixed target; workspaces cleaned.
1337. G027 rejects false committed completion.
1338. G027 rejects false rollback completion.
1339. G027 rejects unapproved MIXED state.
1340. G027 asserts privacy separately from code matching.
1341. G027 asserts lock and descriptor hygiene.
1342. G027 uses deterministic failure ordering.
1343. G027 accepts no field prefix or alternate field.
1344. G027 does not patch production to pass.
1345. G027 runtime result remains PENDING GitHub Actions.
1346. G027 generated artifacts remain outside Git.
1347. G027 expects no ordinary NSError contract.
1348. G027 accepts no any-error match.
1349. G027 accepts no fallback error category.
1350. G027 retains exact success or crash/recovery assertions.
1351. G027 child must terminate by SIGKILL.
1352. G027 durable phase before recovery is quarantined.
1353. G027 recovery runs in a fresh process.
1354. G027 recovered count is exactly one.
1355. G027 parent validates both child statuses.
1356. G027 recovery evidence follows the durable phase.
1357. G028 occurs at the exact deterministic matrix position.
1358. G028 encodes crash after partial install of later target.
1359. G028 invokes the unchanged production authority.
1360. G028 uses one fresh root and fixed fixture data.
1361. G028 confines mutations below the case root.
1362. G028 expected call result is child SIGKILL; fresh production-factory recovery succeeds.
1363. G028 expected public state is recoveredStaleBatchCount=1; targetCount=2.
1364. G028 expected filesystem state is both targets ORIGINAL; no mixed target; workspaces cleaned.
1365. G028 rejects false committed completion.
1366. G028 rejects false rollback completion.
1367. G028 rejects unapproved MIXED state.
1368. G028 asserts privacy separately from code matching.
1369. G028 asserts lock and descriptor hygiene.
1370. G028 uses deterministic failure ordering.
1371. G028 accepts no field prefix or alternate field.
1372. G028 does not patch production to pass.
1373. G028 runtime result remains PENDING GitHub Actions.
1374. G028 generated artifacts remain outside Git.
1375. G028 expects no ordinary NSError contract.
1376. G028 accepts no any-error match.
1377. G028 accepts no fallback error category.
1378. G028 retains exact success or crash/recovery assertions.
1379. G028 child must terminate by SIGKILL.
1380. G028 durable phase before recovery is quarantined.
1381. G028 recovery runs in a fresh process.
1382. G028 recovered count is exactly one.
1383. G028 parent validates both child statuses.
1384. G028 recovery evidence follows the durable phase.
1385. G029 occurs at the exact deterministic matrix position.
1386. G029 encodes crash after durable installed phase.
1387. G029 invokes the unchanged production authority.
1388. G029 uses one fresh root and fixed fixture data.
1389. G029 confines mutations below the case root.
1390. G029 expected call result is child SIGKILL; fresh production-factory recovery succeeds.
1391. G029 expected public state is recoveredStaleBatchCount=1; targetCount=2.
1392. G029 expected filesystem state is both targets ORIGINAL; no mixed target; workspaces cleaned.
1393. G029 rejects false committed completion.
1394. G029 rejects false rollback completion.
1395. G029 rejects unapproved MIXED state.
1396. G029 asserts privacy separately from code matching.
1397. G029 asserts lock and descriptor hygiene.
1398. G029 uses deterministic failure ordering.
1399. G029 accepts no field prefix or alternate field.
1400. G029 does not patch production to pass.
1401. G029 runtime result remains PENDING GitHub Actions.
1402. G029 generated artifacts remain outside Git.
1403. G029 expects no ordinary NSError contract.
1404. G029 accepts no any-error match.
1405. G029 accepts no fallback error category.
1406. G029 retains exact success or crash/recovery assertions.
1407. G029 child must terminate by SIGKILL.
1408. G029 durable phase before recovery is installed.
1409. G029 recovery runs in a fresh process.
1410. G029 recovered count is exactly one.
1411. G029 parent validates both child statuses.
1412. G029 recovery evidence follows the durable phase.
1413. G030 occurs at the exact deterministic matrix position.
1414. G030 encodes crash after durable committed phase.
1415. G030 invokes the unchanged production authority.
1416. G030 uses one fresh root and fixed fixture data.
1417. G030 confines mutations below the case root.
1418. G030 expected call result is child SIGKILL; fresh production-factory recovery succeeds.
1419. G030 expected public state is recoveredStaleBatchCount=1; targetCount=2.
1420. G030 expected filesystem state is both targets INSTALLED; no mixed target; workspaces cleaned.
1421. G030 rejects false committed completion.
1422. G030 rejects false rollback completion.
1423. G030 rejects unapproved MIXED state.
1424. G030 asserts privacy separately from code matching.
1425. G030 asserts lock and descriptor hygiene.
1426. G030 uses deterministic failure ordering.
1427. G030 accepts no field prefix or alternate field.
1428. G030 does not patch production to pass.
1429. G030 runtime result remains PENDING GitHub Actions.
1430. G030 generated artifacts remain outside Git.
1431. G030 expects no ordinary NSError contract.
1432. G030 accepts no any-error match.
1433. G030 accepts no fallback error category.
1434. G030 retains exact success or crash/recovery assertions.
1435. G030 child must terminate by SIGKILL.
1436. G030 durable phase before recovery is committed.
1437. G030 recovery runs in a fresh process.
1438. G030 recovered count is exactly one.
1439. G030 parent validates both child statuses.
1440. G030 recovery evidence follows the durable phase.
1441. O001 occurs at the exact deterministic matrix position.
1442. O001 encodes clean batch with all three item kinds.
1443. O001 invokes the unchanged production authority.
1444. O001 uses one fresh root and fixed fixture data.
1445. O001 confines mutations below the case root.
1446. O001 expected call result is commit YES; error nil; cleanupWarning nil.
1447. O001 expected public state is committed=YES; rollbackPerformed=NO; rollbackComplete=NO; itemCount=3; recovered=0.
1448. O001 expected filesystem state is all three replacements INSTALLED; workspace absent.
1449. O001 rejects false committed completion.
1450. O001 rejects false rollback completion.
1451. O001 rejects unapproved MIXED state.
1452. O001 asserts privacy separately from code matching.
1453. O001 asserts lock and descriptor hygiene.
1454. O001 uses deterministic failure ordering.
1455. O001 accepts no field prefix or alternate field.
1456. O001 does not patch production to pass.
1457. O001 runtime result remains PENDING GitHub Actions.
1458. O001 generated artifacts remain outside Git.
1459. O001 expects no ordinary NSError contract.
1460. O001 accepts no any-error match.
1461. O001 accepts no fallback error category.
1462. O001 retains exact success or crash/recovery assertions.
1463. O002 occurs at the exact deterministic matrix position.
1464. O002 encodes second commit.
1465. O002 invokes the unchanged production authority.
1466. O002 uses one fresh root and fixed fixture data.
1467. O002 confines mutations below the case root.
1468. O002 expected call result is second commit NO.
1469. O002 expected public state is committed remains YES.
1470. O002 expected filesystem state is all installed replacements unchanged.
1471. O002 rejects false committed completion.
1472. O002 rejects false rollback completion.
1473. O002 rejects unapproved MIXED state.
1474. O002 asserts privacy separately from code matching.
1475. O002 asserts lock and descriptor hygiene.
1476. O002 uses deterministic failure ordering.
1477. O002 accepts no field prefix or alternate field.
1478. O002 does not patch production to pass.
1479. O002 runtime result remains PENDING GitHub Actions.
1480. O002 generated artifacts remain outside Git.
1481. O002 exact domain is PXOptionalRestoreTransactionErrorDomain.
1482. O002 exact code is 1 (InvalidInput).
1483. O002 exact field is $.
1484. O002 uses field key PXOptionalRestoreTransactionErrorFieldPathKey.
1485. O003 occurs at the exact deterministic matrix position.
1486. O003 encodes DirectoryContents-only clean commit.
1487. O003 invokes the unchanged production authority.
1488. O003 uses one fresh root and fixed fixture data.
1489. O003 confines mutations below the case root.
1490. O003 expected call result is commit YES; error nil; cleanupWarning nil.
1491. O003 expected public state is committed=YES; rollbackPerformed=NO; rollbackComplete=NO; itemCount=1; recovered=0.
1492. O003 expected filesystem state is selected replacement INSTALLED; workspace absent.
1493. O003 rejects false committed completion.
1494. O003 rejects false rollback completion.
1495. O003 rejects unapproved MIXED state.
1496. O003 asserts privacy separately from code matching.
1497. O003 asserts lock and descriptor hygiene.
1498. O003 uses deterministic failure ordering.
1499. O003 accepts no field prefix or alternate field.
1500. O003 does not patch production to pass.
1501. O003 runtime result remains PENDING GitHub Actions.
1502. O003 generated artifacts remain outside Git.
1503. O003 expects no ordinary NSError contract.
1504. O003 accepts no any-error match.
1505. O003 accepts no fallback error category.
1506. O003 retains exact success or crash/recovery assertions.
1507. O004 occurs at the exact deterministic matrix position.
1508. O004 encodes DirectoryObject-only clean commit.
1509. O004 invokes the unchanged production authority.
1510. O004 uses one fresh root and fixed fixture data.
1511. O004 confines mutations below the case root.
1512. O004 expected call result is commit YES; error nil; cleanupWarning nil.
1513. O004 expected public state is committed=YES; rollbackPerformed=NO; rollbackComplete=NO; itemCount=1; recovered=0.
1514. O004 expected filesystem state is selected replacement INSTALLED; workspace absent.
1515. O004 rejects false committed completion.
1516. O004 rejects false rollback completion.
1517. O004 rejects unapproved MIXED state.
1518. O004 asserts privacy separately from code matching.
1519. O004 asserts lock and descriptor hygiene.
1520. O004 uses deterministic failure ordering.
1521. O004 accepts no field prefix or alternate field.
1522. O004 does not patch production to pass.
1523. O004 runtime result remains PENDING GitHub Actions.
1524. O004 generated artifacts remain outside Git.
1525. O004 expects no ordinary NSError contract.
1526. O004 accepts no any-error match.
1527. O004 accepts no fallback error category.
1528. O004 retains exact success or crash/recovery assertions.
1529. O005 occurs at the exact deterministic matrix position.
1530. O005 encodes FileObject-only clean commit.
1531. O005 invokes the unchanged production authority.
1532. O005 uses one fresh root and fixed fixture data.
1533. O005 confines mutations below the case root.
1534. O005 expected call result is commit YES; error nil; cleanupWarning nil.
1535. O005 expected public state is committed=YES; rollbackPerformed=NO; rollbackComplete=NO; itemCount=1; recovered=0.
1536. O005 expected filesystem state is selected replacement INSTALLED; workspace absent.
1537. O005 rejects false committed completion.
1538. O005 rejects false rollback completion.
1539. O005 rejects unapproved MIXED state.
1540. O005 asserts privacy separately from code matching.
1541. O005 asserts lock and descriptor hygiene.
1542. O005 uses deterministic failure ordering.
1543. O005 accepts no field prefix or alternate field.
1544. O005 does not patch production to pass.
1545. O005 runtime result remains PENDING GitHub Actions.
1546. O005 generated artifacts remain outside Git.
1547. O005 expects no ordinary NSError contract.
1548. O005 accepts no any-error match.
1549. O005 accepts no fallback error category.
1550. O005 retains exact success or crash/recovery assertions.
1551. O006 occurs at the exact deterministic matrix position.
1552. O006 encodes real authority lock contention.
1553. O006 invokes the unchanged production authority.
1554. O006 uses one fresh root and fixed fixture data.
1555. O006 confines mutations below the case root.
1556. O006 expected call result is factory nil.
1557. O006 expected public state is no transaction object.
1558. O006 expected filesystem state is all optional originals intact.
1559. O006 rejects false committed completion.
1560. O006 rejects false rollback completion.
1561. O006 rejects unapproved MIXED state.
1562. O006 asserts privacy separately from code matching.
1563. O006 asserts lock and descriptor hygiene.
1564. O006 uses deterministic failure ordering.
1565. O006 accepts no field prefix or alternate field.
1566. O006 does not patch production to pass.
1567. O006 runtime result remains PENDING GitHub Actions.
1568. O006 generated artifacts remain outside Git.
1569. O006 exact domain is PXOptionalRestoreTransactionErrorDomain.
1570. O006 exact code is 4 (LockFailed).
1571. O006 exact field is $.locks.
1572. O006 uses field key PXOptionalRestoreTransactionErrorFieldPathKey.
1573. O007 occurs at the exact deterministic matrix position.
1574. O007 encodes mutate file-stage st_dev.
1575. O007 invokes the unchanged production authority.
1576. O007 uses one fresh root and fixed fixture data.
1577. O007 confines mutations below the case root.
1578. O007 expected call result is factory nil.
1579. O007 expected public state is no transaction object.
1580. O007 expected filesystem state is all optional originals intact.
1581. O007 rejects false committed completion.
1582. O007 rejects false rollback completion.
1583. O007 rejects unapproved MIXED state.
1584. O007 asserts privacy separately from code matching.
1585. O007 asserts lock and descriptor hygiene.
1586. O007 uses deterministic failure ordering.
1587. O007 accepts no field prefix or alternate field.
1588. O007 does not patch production to pass.
1589. O007 runtime result remains PENDING GitHub Actions.
1590. O007 generated artifacts remain outside Git.
1591. O007 exact domain is PXOptionalRestoreTransactionErrorDomain.
1592. O007 exact code is 5 (CrossDeviceBoundary).
1593. O007 exact field is $.stage.
1594. O007 uses field key PXOptionalRestoreTransactionErrorFieldPathKey.
1595. O008 occurs at the exact deterministic matrix position.
1596. O008 encodes one EINTR on staged-file read.
1597. O008 invokes the unchanged production authority.
1598. O008 uses one fresh root and fixed fixture data.
1599. O008 confines mutations below the case root.
1600. O008 expected call result is commit YES; error nil; cleanupWarning nil.
1601. O008 expected public state is committed=YES; rollbackPerformed=NO; rollbackComplete=NO; itemCount=3; recovered=0.
1602. O008 expected filesystem state is all three replacements INSTALLED; workspace absent.
1603. O008 rejects false committed completion.
1604. O008 rejects false rollback completion.
1605. O008 rejects unapproved MIXED state.
1606. O008 asserts privacy separately from code matching.
1607. O008 asserts lock and descriptor hygiene.
1608. O008 uses deterministic failure ordering.
1609. O008 accepts no field prefix or alternate field.
1610. O008 does not patch production to pass.
1611. O008 runtime result remains PENDING GitHub Actions.
1612. O008 generated artifacts remain outside Git.
1613. O008 expects no ordinary NSError contract.
1614. O008 accepts no any-error match.
1615. O008 accepts no fallback error category.
1616. O008 retains exact success or crash/recovery assertions.
1617. O009 occurs at the exact deterministic matrix position.
1618. O009 encodes workspace creation mkdirat fails ENOSPC.
1619. O009 invokes the unchanged production authority.
1620. O009 uses one fresh root and fixed fixture data.
1621. O009 confines mutations below the case root.
1622. O009 expected call result is commit NO.
1623. O009 expected public state is committed=NO; rollbackPerformed=NO; rollbackComplete=NO.
1624. O009 expected filesystem state is all originals intact; unprepared evidence cleaned.
1625. O009 rejects false committed completion.
1626. O009 rejects false rollback completion.
1627. O009 rejects unapproved MIXED state.
1628. O009 asserts privacy separately from code matching.
1629. O009 asserts lock and descriptor hygiene.
1630. O009 uses deterministic failure ordering.
1631. O009 accepts no field prefix or alternate field.
1632. O009 does not patch production to pass.
1633. O009 runtime result remains PENDING GitHub Actions.
1634. O009 generated artifacts remain outside Git.
1635. O009 exact domain is PXOptionalRestoreTransactionErrorDomain.
1636. O009 exact code is 7 (WorkspaceCreationFailed).
1637. O009 exact field is $.workspace.
1638. O009 uses field key PXOptionalRestoreTransactionErrorFieldPathKey.
1639. O010 occurs at the exact deterministic matrix position.
1640. O010 encodes file replacement open fails EMFILE.
1641. O010 invokes the unchanged production authority.
1642. O010 uses one fresh root and fixed fixture data.
1643. O010 confines mutations below the case root.
1644. O010 expected call result is commit NO.
1645. O010 expected public state is committed=NO; rollbackPerformed=NO; rollbackComplete=NO.
1646. O010 expected filesystem state is all originals intact; unprepared evidence cleaned.
1647. O010 rejects false committed completion.
1648. O010 rejects false rollback completion.
1649. O010 rejects unapproved MIXED state.
1650. O010 asserts privacy separately from code matching.
1651. O010 asserts lock and descriptor hygiene.
1652. O010 uses deterministic failure ordering.
1653. O010 accepts no field prefix or alternate field.
1654. O010 does not patch production to pass.
1655. O010 runtime result remains PENDING GitHub Actions.
1656. O010 generated artifacts remain outside Git.
1657. O010 exact domain is PXOptionalRestoreTransactionErrorDomain.
1658. O010 exact code is 8 (ReplacementPreparationFailed).
1659. O010 exact field is $.replacement.
1660. O010 uses field key PXOptionalRestoreTransactionErrorFieldPathKey.
1661. O011 occurs at the exact deterministic matrix position.
1662. O011 encodes staged-file read fails EIO.
1663. O011 invokes the unchanged production authority.
1664. O011 uses one fresh root and fixed fixture data.
1665. O011 confines mutations below the case root.
1666. O011 expected call result is commit NO.
1667. O011 expected public state is committed=NO; rollbackPerformed=NO; rollbackComplete=NO.
1668. O011 expected filesystem state is all originals intact; unprepared evidence cleaned.
1669. O011 rejects false committed completion.
1670. O011 rejects false rollback completion.
1671. O011 rejects unapproved MIXED state.
1672. O011 asserts privacy separately from code matching.
1673. O011 asserts lock and descriptor hygiene.
1674. O011 uses deterministic failure ordering.
1675. O011 accepts no field prefix or alternate field.
1676. O011 does not patch production to pass.
1677. O011 runtime result remains PENDING GitHub Actions.
1678. O011 generated artifacts remain outside Git.
1679. O011 exact domain is PXOptionalRestoreTransactionErrorDomain.
1680. O011 exact code is 9 (ReplacementMismatch).
1681. O011 exact field is $.replacement.
1682. O011 uses field key PXOptionalRestoreTransactionErrorFieldPathKey.
1683. O012 occurs at the exact deterministic matrix position.
1684. O012 encodes replacement write fails ENOSPC.
1685. O012 invokes the unchanged production authority.
1686. O012 uses one fresh root and fixed fixture data.
1687. O012 confines mutations below the case root.
1688. O012 expected call result is commit NO.
1689. O012 expected public state is committed=NO; rollbackPerformed=NO; rollbackComplete=NO.
1690. O012 expected filesystem state is all originals intact; unprepared evidence cleaned.
1691. O012 rejects false committed completion.
1692. O012 rejects false rollback completion.
1693. O012 rejects unapproved MIXED state.
1694. O012 asserts privacy separately from code matching.
1695. O012 asserts lock and descriptor hygiene.
1696. O012 uses deterministic failure ordering.
1697. O012 accepts no field prefix or alternate field.
1698. O012 does not patch production to pass.
1699. O012 runtime result remains PENDING GitHub Actions.
1700. O012 generated artifacts remain outside Git.
1701. O012 exact domain is PXOptionalRestoreTransactionErrorDomain.
1702. O012 exact code is 9 (ReplacementMismatch).
1703. O012 exact field is $.replacement.
1704. O012 uses field key PXOptionalRestoreTransactionErrorFieldPathKey.
1705. O013 occurs at the exact deterministic matrix position.
1706. O013 encodes replacement-file fsync fails EIO.
1707. O013 invokes the unchanged production authority.
1708. O013 uses one fresh root and fixed fixture data.
1709. O013 confines mutations below the case root.
1710. O013 expected call result is commit NO.
1711. O013 expected public state is committed=NO; rollbackPerformed=NO; rollbackComplete=NO.
1712. O013 expected filesystem state is all originals intact; unprepared evidence cleaned.
1713. O013 rejects false committed completion.
1714. O013 rejects false rollback completion.
1715. O013 rejects unapproved MIXED state.
1716. O013 asserts privacy separately from code matching.
1717. O013 asserts lock and descriptor hygiene.
1718. O013 uses deterministic failure ordering.
1719. O013 accepts no field prefix or alternate field.
1720. O013 does not patch production to pass.
1721. O013 runtime result remains PENDING GitHub Actions.
1722. O013 generated artifacts remain outside Git.
1723. O013 exact domain is PXOptionalRestoreTransactionErrorDomain.
1724. O013 exact code is 9 (ReplacementMismatch).
1725. O013 exact field is $.replacement.
1726. O013 uses field key PXOptionalRestoreTransactionErrorFieldPathKey.
1727. O014 occurs at the exact deterministic matrix position.
1728. O014 encodes prepared leader-journal write fails.
1729. O014 invokes the unchanged production authority.
1730. O014 uses one fresh root and fixed fixture data.
1731. O014 confines mutations below the case root.
1732. O014 expected call result is commit NO.
1733. O014 expected public state is committed=NO; rollbackPerformed=YES; rollbackComplete=YES.
1734. O014 expected filesystem state is all three originals restored; Keychain excluded; workspace cleaned.
1735. O014 rejects false committed completion.
1736. O014 rejects false rollback completion.
1737. O014 rejects unapproved MIXED state.
1738. O014 asserts privacy separately from code matching.
1739. O014 asserts lock and descriptor hygiene.
1740. O014 uses deterministic failure ordering.
1741. O014 accepts no field prefix or alternate field.
1742. O014 does not patch production to pass.
1743. O014 runtime result remains PENDING GitHub Actions.
1744. O014 generated artifacts remain outside Git.
1745. O014 exact domain is PXOptionalRestoreTransactionErrorDomain.
1746. O014 exact code is 10 (JournalCreationFailed).
1747. O014 exact field is $.journal.
1748. O014 uses field key PXOptionalRestoreTransactionErrorFieldPathKey.
1749. O015 occurs at the exact deterministic matrix position.
1750. O015 encodes DirectoryContents quarantine rename fails.
1751. O015 invokes the unchanged production authority.
1752. O015 uses one fresh root and fixed fixture data.
1753. O015 confines mutations below the case root.
1754. O015 expected call result is commit NO.
1755. O015 expected public state is committed=NO; rollbackPerformed=YES; rollbackComplete=YES.
1756. O015 expected filesystem state is all three originals restored; Keychain excluded; workspace cleaned.
1757. O015 rejects false committed completion.
1758. O015 rejects false rollback completion.
1759. O015 rejects unapproved MIXED state.
1760. O015 asserts privacy separately from code matching.
1761. O015 asserts lock and descriptor hygiene.
1762. O015 uses deterministic failure ordering.
1763. O015 accepts no field prefix or alternate field.
1764. O015 does not patch production to pass.
1765. O015 runtime result remains PENDING GitHub Actions.
1766. O015 generated artifacts remain outside Git.
1767. O015 exact domain is PXOptionalRestoreTransactionErrorDomain.
1768. O015 exact code is 12 (QuarantineFailed).
1769. O015 exact field is $.transaction.quarantine.
1770. O015 uses field key PXOptionalRestoreTransactionErrorFieldPathKey.
1771. O016 occurs at the exact deterministic matrix position.
1772. O016 encodes DirectoryObject quarantine rename fails.
1773. O016 invokes the unchanged production authority.
1774. O016 uses one fresh root and fixed fixture data.
1775. O016 confines mutations below the case root.
1776. O016 expected call result is commit NO.
1777. O016 expected public state is committed=NO; rollbackPerformed=YES; rollbackComplete=YES.
1778. O016 expected filesystem state is all three originals restored; Keychain excluded; workspace cleaned.
1779. O016 rejects false committed completion.
1780. O016 rejects false rollback completion.
1781. O016 rejects unapproved MIXED state.
1782. O016 asserts privacy separately from code matching.
1783. O016 asserts lock and descriptor hygiene.
1784. O016 uses deterministic failure ordering.
1785. O016 accepts no field prefix or alternate field.
1786. O016 does not patch production to pass.
1787. O016 runtime result remains PENDING GitHub Actions.
1788. O016 generated artifacts remain outside Git.
1789. O016 exact domain is PXOptionalRestoreTransactionErrorDomain.
1790. O016 exact code is 12 (QuarantineFailed).
1791. O016 exact field is $.transaction.quarantine.
1792. O016 uses field key PXOptionalRestoreTransactionErrorFieldPathKey.
1793. O017 occurs at the exact deterministic matrix position.
1794. O017 encodes FileObject quarantine rename fails.
1795. O017 invokes the unchanged production authority.
1796. O017 uses one fresh root and fixed fixture data.
1797. O017 confines mutations below the case root.
1798. O017 expected call result is commit NO.
1799. O017 expected public state is committed=NO; rollbackPerformed=YES; rollbackComplete=YES.
1800. O017 expected filesystem state is all three originals restored; Keychain excluded; workspace cleaned.
1801. O017 rejects false committed completion.
1802. O017 rejects false rollback completion.
1803. O017 rejects unapproved MIXED state.
1804. O017 asserts privacy separately from code matching.
1805. O017 asserts lock and descriptor hygiene.
1806. O017 uses deterministic failure ordering.
1807. O017 accepts no field prefix or alternate field.
1808. O017 does not patch production to pass.
1809. O017 runtime result remains PENDING GitHub Actions.
1810. O017 generated artifacts remain outside Git.
1811. O017 exact domain is PXOptionalRestoreTransactionErrorDomain.
1812. O017 exact code is 12 (QuarantineFailed).
1813. O017 exact field is $.transaction.quarantine.
1814. O017 uses field key PXOptionalRestoreTransactionErrorFieldPathKey.
1815. O018 occurs at the exact deterministic matrix position.
1816. O018 encodes quarantined journal publication fails.
1817. O018 invokes the unchanged production authority.
1818. O018 uses one fresh root and fixed fixture data.
1819. O018 confines mutations below the case root.
1820. O018 expected call result is commit NO.
1821. O018 expected public state is committed=NO; rollbackPerformed=YES; rollbackComplete=YES.
1822. O018 expected filesystem state is all three originals restored; Keychain excluded; workspace cleaned.
1823. O018 rejects false committed completion.
1824. O018 rejects false rollback completion.
1825. O018 rejects unapproved MIXED state.
1826. O018 asserts privacy separately from code matching.
1827. O018 asserts lock and descriptor hygiene.
1828. O018 uses deterministic failure ordering.
1829. O018 accepts no field prefix or alternate field.
1830. O018 does not patch production to pass.
1831. O018 runtime result remains PENDING GitHub Actions.
1832. O018 generated artifacts remain outside Git.
1833. O018 exact domain is PXOptionalRestoreTransactionErrorDomain.
1834. O018 exact code is 10 (JournalCreationFailed).
1835. O018 exact field is $.journal.
1836. O018 uses field key PXOptionalRestoreTransactionErrorFieldPathKey.
1837. O019 occurs at the exact deterministic matrix position.
1838. O019 encodes DirectoryContents install rename fails.
1839. O019 invokes the unchanged production authority.
1840. O019 uses one fresh root and fixed fixture data.
1841. O019 confines mutations below the case root.
1842. O019 expected call result is commit NO.
1843. O019 expected public state is committed=NO; rollbackPerformed=YES; rollbackComplete=YES.
1844. O019 expected filesystem state is all three originals restored; Keychain excluded; workspace cleaned.
1845. O019 rejects false committed completion.
1846. O019 rejects false rollback completion.
1847. O019 rejects unapproved MIXED state.
1848. O019 asserts privacy separately from code matching.
1849. O019 asserts lock and descriptor hygiene.
1850. O019 uses deterministic failure ordering.
1851. O019 accepts no field prefix or alternate field.
1852. O019 does not patch production to pass.
1853. O019 runtime result remains PENDING GitHub Actions.
1854. O019 generated artifacts remain outside Git.
1855. O019 exact domain is PXOptionalRestoreTransactionErrorDomain.
1856. O019 exact code is 13 (CommitFailed).
1857. O019 exact field is $.transaction.commit.
1858. O019 uses field key PXOptionalRestoreTransactionErrorFieldPathKey.
1859. O020 occurs at the exact deterministic matrix position.
1860. O020 encodes DirectoryObject install rename fails.
1861. O020 invokes the unchanged production authority.
1862. O020 uses one fresh root and fixed fixture data.
1863. O020 confines mutations below the case root.
1864. O020 expected call result is commit NO.
1865. O020 expected public state is committed=NO; rollbackPerformed=YES; rollbackComplete=YES.
1866. O020 expected filesystem state is all three originals restored; Keychain excluded; workspace cleaned.
1867. O020 rejects false committed completion.
1868. O020 rejects false rollback completion.
1869. O020 rejects unapproved MIXED state.
1870. O020 asserts privacy separately from code matching.
1871. O020 asserts lock and descriptor hygiene.
1872. O020 uses deterministic failure ordering.
1873. O020 accepts no field prefix or alternate field.
1874. O020 does not patch production to pass.
1875. O020 runtime result remains PENDING GitHub Actions.
1876. O020 generated artifacts remain outside Git.
1877. O020 exact domain is PXOptionalRestoreTransactionErrorDomain.
1878. O020 exact code is 13 (CommitFailed).
1879. O020 exact field is $.transaction.commit.
1880. O020 uses field key PXOptionalRestoreTransactionErrorFieldPathKey.
1881. O021 occurs at the exact deterministic matrix position.
1882. O021 encodes FileObject install rename fails.
1883. O021 invokes the unchanged production authority.
1884. O021 uses one fresh root and fixed fixture data.
1885. O021 confines mutations below the case root.
1886. O021 expected call result is commit NO.
1887. O021 expected public state is committed=NO; rollbackPerformed=YES; rollbackComplete=YES.
1888. O021 expected filesystem state is all three originals restored; Keychain excluded; workspace cleaned.
1889. O021 rejects false committed completion.
1890. O021 rejects false rollback completion.
1891. O021 rejects unapproved MIXED state.
1892. O021 asserts privacy separately from code matching.
1893. O021 asserts lock and descriptor hygiene.
1894. O021 uses deterministic failure ordering.
1895. O021 accepts no field prefix or alternate field.
1896. O021 does not patch production to pass.
1897. O021 runtime result remains PENDING GitHub Actions.
1898. O021 generated artifacts remain outside Git.
1899. O021 exact domain is PXOptionalRestoreTransactionErrorDomain.
1900. O021 exact code is 13 (CommitFailed).
1901. O021 exact field is $.transaction.commit.
1902. O021 uses field key PXOptionalRestoreTransactionErrorFieldPathKey.
1903. O022 occurs at the exact deterministic matrix position.
1904. O022 encodes installed journal publication fails.
1905. O022 invokes the unchanged production authority.
1906. O022 uses one fresh root and fixed fixture data.
1907. O022 confines mutations below the case root.
1908. O022 expected call result is commit NO.
1909. O022 expected public state is committed=NO; rollbackPerformed=YES; rollbackComplete=YES.
1910. O022 expected filesystem state is all three originals restored; Keychain excluded; workspace cleaned.
1911. O022 rejects false committed completion.
1912. O022 rejects false rollback completion.
1913. O022 rejects unapproved MIXED state.
1914. O022 asserts privacy separately from code matching.
1915. O022 asserts lock and descriptor hygiene.
1916. O022 uses deterministic failure ordering.
1917. O022 accepts no field prefix or alternate field.
1918. O022 does not patch production to pass.
1919. O022 runtime result remains PENDING GitHub Actions.
1920. O022 generated artifacts remain outside Git.
1921. O022 exact domain is PXOptionalRestoreTransactionErrorDomain.
1922. O022 exact code is 10 (JournalCreationFailed).
1923. O022 exact field is $.journal.
1924. O022 uses field key PXOptionalRestoreTransactionErrorFieldPathKey.
1925. O023 occurs at the exact deterministic matrix position.
1926. O023 encodes committed journal publication fails.
1927. O023 invokes the unchanged production authority.
1928. O023 uses one fresh root and fixed fixture data.
1929. O023 confines mutations below the case root.
1930. O023 expected call result is commit NO.
1931. O023 expected public state is committed=NO; rollbackPerformed=YES; rollbackComplete=YES.
1932. O023 expected filesystem state is all three originals restored; Keychain excluded; workspace cleaned.
1933. O023 rejects false committed completion.
1934. O023 rejects false rollback completion.
1935. O023 rejects unapproved MIXED state.
1936. O023 asserts privacy separately from code matching.
1937. O023 asserts lock and descriptor hygiene.
1938. O023 uses deterministic failure ordering.
1939. O023 accepts no field prefix or alternate field.
1940. O023 does not patch production to pass.
1941. O023 runtime result remains PENDING GitHub Actions.
1942. O023 generated artifacts remain outside Git.
1943. O023 exact domain is PXOptionalRestoreTransactionErrorDomain.
1944. O023 exact code is 10 (JournalCreationFailed).
1945. O023 exact field is $.journal.
1946. O023 uses field key PXOptionalRestoreTransactionErrorFieldPathKey.
1947. O024 occurs at the exact deterministic matrix position.
1948. O024 encodes rollback installed replacement-to-new rename fails.
1949. O024 invokes the unchanged production authority.
1950. O024 uses one fresh root and fixed fixture data.
1951. O024 confines mutations below the case root.
1952. O024 expected call result is commit NO.
1953. O024 expected public state is committed=NO; rollbackPerformed=YES; rollbackComplete=NO.
1954. O024 expected filesystem state is ROLLBACK_EVIDENCE retained; no false completion.
1955. O024 rejects false committed completion.
1956. O024 rejects false rollback completion.
1957. O024 rejects unapproved MIXED state.
1958. O024 asserts privacy separately from code matching.
1959. O024 asserts lock and descriptor hygiene.
1960. O024 uses deterministic failure ordering.
1961. O024 accepts no field prefix or alternate field.
1962. O024 does not patch production to pass.
1963. O024 runtime result remains PENDING GitHub Actions.
1964. O024 generated artifacts remain outside Git.
1965. O024 exact domain is PXOptionalRestoreTransactionErrorDomain.
1966. O024 exact code is 14 (RollbackFailed).
1967. O024 exact field is $.transaction.rollback.new.
1968. O024 uses field key PXOptionalRestoreTransactionErrorFieldPathKey.
1969. O025 occurs at the exact deterministic matrix position.
1970. O025 encodes rollback original-object restore fails.
1971. O025 invokes the unchanged production authority.
1972. O025 uses one fresh root and fixed fixture data.
1973. O025 confines mutations below the case root.
1974. O025 expected call result is commit NO.
1975. O025 expected public state is committed=NO; rollbackPerformed=YES; rollbackComplete=NO.
1976. O025 expected filesystem state is ROLLBACK_EVIDENCE retained; no false completion.
1977. O025 rejects false committed completion.
1978. O025 rejects false rollback completion.
1979. O025 rejects unapproved MIXED state.
1980. O025 asserts privacy separately from code matching.
1981. O025 asserts lock and descriptor hygiene.
1982. O025 uses deterministic failure ordering.
1983. O025 accepts no field prefix or alternate field.
1984. O025 does not patch production to pass.
1985. O025 runtime result remains PENDING GitHub Actions.
1986. O025 generated artifacts remain outside Git.
1987. O025 exact domain is PXOptionalRestoreTransactionErrorDomain.
1988. O025 exact code is 14 (RollbackFailed).
1989. O025 exact field is $.transaction.rollback.original.
1990. O025 uses field key PXOptionalRestoreTransactionErrorFieldPathKey.
1991. O026 occurs at the exact deterministic matrix position.
1992. O026 encodes cleanup unlink fails after committed decision.
1993. O026 invokes the unchanged production authority.
1994. O026 uses one fresh root and fixed fixture data.
1995. O026 confines mutations below the case root.
1996. O026 expected call result is commit YES; error nil; cleanupWarning nonnil.
1997. O026 expected public state is committed=YES; rollbackPerformed=NO.
1998. O026 expected filesystem state is all replacements INSTALLED; confined evidence retained.
1999. O026 rejects false committed completion.
2000. O026 rejects false rollback completion.
2001. O026 rejects unapproved MIXED state.
2002. O026 asserts privacy separately from code matching.
2003. O026 asserts lock and descriptor hygiene.
2004. O026 uses deterministic failure ordering.
2005. O026 accepts no field prefix or alternate field.
2006. O026 does not patch production to pass.
2007. O026 runtime result remains PENDING GitHub Actions.
2008. O026 generated artifacts remain outside Git.
2009. O026 exact domain is PXOptionalRestoreTransactionErrorDomain.
2010. O026 exact code is 15 (CleanupFailed).
2011. O026 exact field is $.transaction.cleanup.
2012. O026 uses field key PXOptionalRestoreTransactionErrorFieldPathKey.
2013. O027 occurs at the exact deterministic matrix position.
2014. O027 encodes crash after durable prepared phase.
2015. O027 invokes the unchanged production authority.
2016. O027 uses one fresh root and fixed fixture data.
2017. O027 confines mutations below the case root.
2018. O027 expected call result is child SIGKILL; fresh production-factory recovery succeeds.
2019. O027 expected public state is recoveredStaleTransactionCount=1; itemCount=3.
2020. O027 expected filesystem state is all optional originals restored; workspace cleaned; Keychain excluded.
2021. O027 rejects false committed completion.
2022. O027 rejects false rollback completion.
2023. O027 rejects unapproved MIXED state.
2024. O027 asserts privacy separately from code matching.
2025. O027 asserts lock and descriptor hygiene.
2026. O027 uses deterministic failure ordering.
2027. O027 accepts no field prefix or alternate field.
2028. O027 does not patch production to pass.
2029. O027 runtime result remains PENDING GitHub Actions.
2030. O027 generated artifacts remain outside Git.
2031. O027 expects no ordinary NSError contract.
2032. O027 accepts no any-error match.
2033. O027 accepts no fallback error category.
2034. O027 retains exact success or crash/recovery assertions.
2035. O027 child must terminate by SIGKILL.
2036. O027 durable phase before recovery is prepared.
2037. O027 recovery runs in a fresh process.
2038. O027 recovered count is exactly one.
2039. O027 parent validates both child statuses.
2040. O027 recovery evidence follows the durable phase.
2041. O028 occurs at the exact deterministic matrix position.
2042. O028 encodes crash after partial quarantine.
2043. O028 invokes the unchanged production authority.
2044. O028 uses one fresh root and fixed fixture data.
2045. O028 confines mutations below the case root.
2046. O028 expected call result is child SIGKILL; fresh production-factory recovery succeeds.
2047. O028 expected public state is recoveredStaleTransactionCount=1; itemCount=3.
2048. O028 expected filesystem state is all optional originals restored; workspace cleaned; Keychain excluded.
2049. O028 rejects false committed completion.
2050. O028 rejects false rollback completion.
2051. O028 rejects unapproved MIXED state.
2052. O028 asserts privacy separately from code matching.
2053. O028 asserts lock and descriptor hygiene.
2054. O028 uses deterministic failure ordering.
2055. O028 accepts no field prefix or alternate field.
2056. O028 does not patch production to pass.
2057. O028 runtime result remains PENDING GitHub Actions.
2058. O028 generated artifacts remain outside Git.
2059. O028 expects no ordinary NSError contract.
2060. O028 accepts no any-error match.
2061. O028 accepts no fallback error category.
2062. O028 retains exact success or crash/recovery assertions.
2063. O028 child must terminate by SIGKILL.
2064. O028 durable phase before recovery is prepared.
2065. O028 recovery runs in a fresh process.
2066. O028 recovered count is exactly one.
2067. O028 parent validates both child statuses.
2068. O028 recovery evidence follows the durable phase.
2069. O029 occurs at the exact deterministic matrix position.
2070. O029 encodes crash after durable installed phase.
2071. O029 invokes the unchanged production authority.
2072. O029 uses one fresh root and fixed fixture data.
2073. O029 confines mutations below the case root.
2074. O029 expected call result is child SIGKILL; fresh production-factory recovery succeeds.
2075. O029 expected public state is recoveredStaleTransactionCount=1; itemCount=3.
2076. O029 expected filesystem state is all optional originals restored; workspace cleaned; Keychain excluded.
2077. O029 rejects false committed completion.
2078. O029 rejects false rollback completion.
2079. O029 rejects unapproved MIXED state.
2080. O029 asserts privacy separately from code matching.
2081. O029 asserts lock and descriptor hygiene.
2082. O029 uses deterministic failure ordering.
2083. O029 accepts no field prefix or alternate field.
2084. O029 does not patch production to pass.
2085. O029 runtime result remains PENDING GitHub Actions.
2086. O029 generated artifacts remain outside Git.
2087. O029 expects no ordinary NSError contract.
2088. O029 accepts no any-error match.
2089. O029 accepts no fallback error category.
2090. O029 retains exact success or crash/recovery assertions.
2091. O029 child must terminate by SIGKILL.
2092. O029 durable phase before recovery is installed.
2093. O029 recovery runs in a fresh process.
2094. O029 recovered count is exactly one.
2095. O029 parent validates both child statuses.
2096. O029 recovery evidence follows the durable phase.
2097. O030 occurs at the exact deterministic matrix position.
2098. O030 encodes crash after durable committed phase.
2099. O030 invokes the unchanged production authority.
2100. O030 uses one fresh root and fixed fixture data.
2101. O030 confines mutations below the case root.
2102. O030 expected call result is child SIGKILL; fresh production-factory recovery succeeds.
2103. O030 expected public state is recoveredStaleTransactionCount=1; itemCount=3.
2104. O030 expected filesystem state is all replacements INSTALLED; workspace cleaned; Keychain excluded.
2105. O030 rejects false committed completion.
2106. O030 rejects false rollback completion.
2107. O030 rejects unapproved MIXED state.
2108. O030 asserts privacy separately from code matching.
2109. O030 asserts lock and descriptor hygiene.
2110. O030 uses deterministic failure ordering.
2111. O030 accepts no field prefix or alternate field.
2112. O030 does not patch production to pass.
2113. O030 runtime result remains PENDING GitHub Actions.
2114. O030 generated artifacts remain outside Git.
2115. O030 expects no ordinary NSError contract.
2116. O030 accepts no any-error match.
2117. O030 accepts no fallback error category.
2118. O030 retains exact success or crash/recovery assertions.
2119. O030 child must terminate by SIGKILL.
2120. O030 durable phase before recovery is committed.
2121. O030 recovery runs in a fresh process.
2122. O030 recovered count is exactly one.
2123. O030 parent validates both child statuses.
2124. O030 recovery evidence follows the durable phase.

Explicit scenario count: 2124

## Final boundaries

No production bug fix, TASK-6.5 review, Keychain fault injection, backup-publication fault injection, coordinator update, push or TASK-6.6 work was performed. Generated executables, object files, journals and snapshots committed = NO.

GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
