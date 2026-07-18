# TASK-4.2 — Define Reliable Keychain Helper Exit Codes

- Status: READY
- Phase: 4 — Keychain Safety
- Baseline: `1a59e96258651aa9c6aa8d77a1e6debea67ab524`
- Depends on: TASK-4.1 accepted and completed
- Next task: TASK-4.3 remains locked

## Objective

Replace the ambiguous legacy Keychain helper/script process-status convention with one stable, documented and fail-closed exit-code taxonomy.

TASK-4.2 owns only process exit classification. It must preserve the TASK-4.1 machine-result schema and framing, Keychain Security operations, restore pre-delete behavior, per-item mutation semantics, selected access groups, script temporary workspace paths, manager/cleaner/bridge source and UI behavior.

The direct `backup_helper` currently uses legacy values `0`, `1` and `2`; the documented access-denied value `3` is not actively selected. Backup and restore may exit zero for Partial results, wipe has inconsistent treatment of warnings/errors, and the shell wrapper collapses nearly every pre-helper failure to `1`. TASK-4.2 makes these states stable without parsing or extending the machine payload.

## Mandatory reading

Read before editing:

```text
docs/backup-restore-hardening/reviews/TASK-4.1-REVIEW.md
docs/backup-restore-hardening/reports/TASK-4.1-REPORT.md
KeychainHelper/PXKeychainHelperResult.h
KeychainHelper/PXKeychainHelperResult.m
KeychainHelper/KeychainBackupHelper.h
KeychainHelper/KeychainBackupHelper.m
KeychainHelper/backup_helper.m
scripts/keychain_backup.sh
Makefile
AppDataBackupManager.m
AppDataCleaner.m
WeaponXKeychainBridge/Tweak.m
```

Manager, cleaner and bridge are audit inputs only and remain protected.

## Authorized production scope

Only create or modify:

```text
A KeychainHelper/PXKeychainHelperExitCode.h
M KeychainHelper/backup_helper.m
M scripts/keychain_backup.sh
```

Create the report:

```text
A docs/backup-restore-hardening/reports/TASK-4.2-REPORT.md
```

The implementation commit must contain exactly these four files.

## Protected files

Do not modify:

```text
KeychainHelper/PXKeychainHelperResult.h
KeychainHelper/PXKeychainHelperResult.m
KeychainHelper/KeychainBackupHelper.h
KeychainHelper/KeychainBackupHelper.m
Makefile
AppDataBackupManager.h
AppDataBackupManager.m
AppDataCleaner.h
AppDataCleaner.m
WeaponXKeychainBridge/Tweak.m
WeaponXKeychainBridge.plist
keychain_base_ent.plist
BackupKeychainGroupsViewController.h/.m
KeychainGroupsViewController.h/.m
ProjectXTweak/KeychainHooks.x
common/KeychainUUIDManager.h/.m
all Phase-1 through Phase-3 production source
all Restore plan/result/transaction/staging source
all UI/controller source
all coordinator documentation other than the required TASK-4.2 report
```

Do not stage, revert, delete, reformat or rewrite coordinator-owned modified/untracked documentation.

## Baseline evidence

Before editing, record:

```text
git status --short --untracked-files=all
git rev-parse HEAD
git log -8 --oneline
git diff --check
```

Record SHA-256 and byte size before/after for every protected production file above and for all TASK-4.1 source.

# Part A — Public exit-code contract

## New header

Create:

```text
KeychainHelper/PXKeychainHelperExitCode.h
```

The header imports Foundation, uses `NS_ASSUME_NONNULL_BEGIN/END`, and declares exactly one enum:

```objc
typedef NS_ENUM(NSInteger, PXKeychainHelperExitCode) {
    PXKeychainHelperExitCodeCompleted = 0,
    PXKeychainHelperExitCodePartial = 10,
    PXKeychainHelperExitCodeInvalidArguments = 20,
    PXKeychainHelperExitCodeInvalidInput = 21,
    PXKeychainHelperExitCodeAccessDenied = 30,
    PXKeychainHelperExitCodeOperationFailed = 40,
    PXKeychainHelperExitCodeProtocolFailure = 50,
    PXKeychainHelperExitCodeHelperUnavailable = 60,
    PXKeychainHelperExitCodeTargetUnavailable = 61,
    PXKeychainHelperExitCodeEntitlementFailure = 62,
    PXKeychainHelperExitCodeWorkspaceFailure = 63,
    PXKeychainHelperExitCodeSigningFailure = 64,
    PXKeychainHelperExitCodeDependencyUnavailable = 65,
};
```

Do not add aliases, deprecated legacy values, helper functions, classes, strings or mutable state.

All values are within portable process-exit range `0...255`.

## Taxonomy

### Direct-helper codes

The direct `backup_helper` may return only:

```text
0   Completed
10  Partial
20  InvalidArguments
21  InvalidInput
30  AccessDenied
40  OperationFailed
50  ProtocolFailure
```

### Wrapper-only codes

`scripts/keychain_backup.sh` may additionally return:

```text
60  HelperUnavailable
61  TargetUnavailable
62  EntitlementFailure
63  WorkspaceFailure
64  SigningFailure
65  DependencyUnavailable
```

The direct Objective-C helper must never return `60...65`.

The shell wrapper must never translate a recognized direct-helper code into another recognized code.

# Part B — Direct helper exit selection

## Import

`KeychainHelper/backup_helper.m` imports exactly once:

```objc
#import "PXKeychainHelperExitCode.h"
```

Preserve the existing one-time import of `PXKeychainHelperResult.h`.

## Completion mapping

A valid TASK-4.1 result maps exactly:

```text
Completed -> PXKeychainHelperExitCodeCompleted (0)
Partial   -> PXKeychainHelperExitCodePartial (10)
Failed    -> one of 20, 21, 30 or 40 using the fatal category below
```

This mapping applies uniformly to backup, restore and wipe.

Consequences that are intentional in TASK-4.2:

- backup Partial changes from exit `0` to `10`;
- restore Partial changes from exit `0` to `10`;
- wipe Partial changes from legacy `0` or `2` to `10`;
- Completed remains `0`;
- fatal operations no longer use generic legacy `1`/`2`.

The structured result remains the factual source. Exit code is a stable coarse policy projection and must agree with its completion.

## Failed-result mapping

Map a Failed result using exact operation/error facts, without parsing human messages.

### InvalidArguments — 20

Use `PXKeychainHelperExitCodeInvalidArguments` for:

- missing `--action`;
- unknown action;
- missing backup `--file`;
- missing backup `--groups`;
- missing restore `--file`;
- missing wipe `--groups`;
- missing list `--groups`;
- unreachable dispatch/default argument failure;
- fatal `PXKeychainBackupErrorInvalidArguments`;
- fatal `PXKeychainBackupErrorNoAccessGroups`.

Known-action argument failures retain their selected TASK-4.1 operation in the machine result. Missing/unknown action remains operation Unknown.

### InvalidInput — 21

Use `PXKeychainHelperExitCodeInvalidInput` only for restore input rejected after a syntactically valid invocation:

- fatal `PXKeychainBackupErrorFileIO` while operation is Restore;
- fatal `PXKeychainBackupErrorInvalidBackupFile` while operation is Restore.

Do not use InvalidInput for backup output write/serialization failures. Those are OperationFailed.

### AccessDenied — 30

Use `PXKeychainHelperExitCodeAccessDenied` only when:

```text
fatal NSError.domain == PXKeychainBackupErrorDomain
fatal NSError.code == PXKeychainBackupErrorSecurityFramework
```

Do not parse localized descriptions, warning strings, `OSStatus` text or stderr.

A nonnil operation result with Security warnings/errors is Partial (`10`), not AccessDenied, because the operation produced a factual partial result rather than a fatal error.

### OperationFailed — 40

Use `PXKeychainHelperExitCodeOperationFailed` for every other valid Failed result, including:

- backup `PXKeychainBackupErrorFileIO`;
- fatal `PXKeychainBackupErrorUnknown`;
- nil operation result with no NSError after synthetic Unknown creation;
- foreign or future fatal domains/codes;
- any critical operation failure not explicitly classified above.

Do not expose raw NSError codes as process exits.

## ProtocolFailure — 50

Use `PXKeychainHelperExitCodeProtocolFailure` when the TASK-4.1 result protocol cannot be emitted consistently:

- `PXCreateStructuredResult` returns nil;
- `machineReadableLine` is absent/empty;
- result completion and selected exit code are incompatible;
- an internal finalization invariant fails;
- the emitter must use exact `PXKEYCHAIN_HELPER_RESULT_V1=INVALID` fallback.

ProtocolFailure must override the intended business exit code because callers cannot trust a missing/invalid machine result.

Do not serialize the construction error or add an exit-code field to the payload.

## One finalization path

Refactor the TASK-4.1 terminal code through exactly one file-local finalizer, for example:

```text
PXFinishStructuredInvocation
```

The exact name may differ, but the implementation must have one semantic finalizer that:

1. receives the constructed result and intended enum exit code;
2. validates result/exit compatibility;
3. calls the existing single emitter exactly once;
4. returns ProtocolFailure `50` when result/framing/invariant is invalid;
5. otherwise returns the intended exact enum value.

Compatibility matrix:

```text
Completed result: only 0
Partial result:   only 10
Failed result:    only 20, 21, 30 or 40
nil/invalid:      exactly 50 plus INVALID line
```

Every non-help direct-helper terminal path must return through this finalizer.

`--help` remains exit `0`, prints current usage and emits no result line.

## Direct-helper static requirements

After TASK-4.2:

```text
raw `return 1;` sites in backup_helper.m: 0
raw `return 2;` sites in backup_helper.m: 0
raw `return 3;` sites in backup_helper.m: 0
wrapper-only enum returns in helper:       0
finalizer definitions:                     1
emitter definitions:                       1
result-line fprintf sites:                 1
fflush(stdout) sites:                      1
INVALID fallback literal sites:            1
```

All non-help exits use named enum constants or the finalizer result. No magic numeric business return literals.

# Part C — Shell-wrapper exit mapping

## Shell constants

Near the immutable configuration section of `scripts/keychain_backup.sh`, define exactly thirteen readonly scalar constants mirroring the Objective-C enum:

```bash
readonly PX_KEYCHAIN_EXIT_COMPLETED=0
readonly PX_KEYCHAIN_EXIT_PARTIAL=10
readonly PX_KEYCHAIN_EXIT_INVALID_ARGUMENTS=20
readonly PX_KEYCHAIN_EXIT_INVALID_INPUT=21
readonly PX_KEYCHAIN_EXIT_ACCESS_DENIED=30
readonly PX_KEYCHAIN_EXIT_OPERATION_FAILED=40
readonly PX_KEYCHAIN_EXIT_PROTOCOL_FAILURE=50
readonly PX_KEYCHAIN_EXIT_HELPER_UNAVAILABLE=60
readonly PX_KEYCHAIN_EXIT_TARGET_UNAVAILABLE=61
readonly PX_KEYCHAIN_EXIT_ENTITLEMENT_FAILURE=62
readonly PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE=63
readonly PX_KEYCHAIN_EXIT_SIGNING_FAILURE=64
readonly PX_KEYCHAIN_EXIT_DEPENDENCY_UNAVAILABLE=65
```

Do not export them to child environment. Do not derive them from untrusted input.

## Recognized helper status normalization

Create one shell function that accepts a raw child status and permits exactly these direct-helper codes:

```text
0 10 20 21 30 40 50
```

Behavior:

- recognized direct code: return/pass it unchanged;
- every other child status, including `1`, `2`, `3`, `126`, `127`, signal-derived values and future unknown values: log the raw numeric status in a bounded human diagnostic and normalize to `PX_KEYCHAIN_EXIT_OPERATION_FAILED` (`40`).

Do not parse stdout/stderr or the TASK-4.1 base64 line in TASK-4.2.

Use the normalization function after all four helper executions:

```text
do_backup
do_restore
do_wipe
do_list
```

## Wrapper pre-helper mapping

Map existing explicit shell failure branches as follows. Do not invent new filesystem/path checks or secure-workspace behavior.

### InvalidArguments — 20

- fewer than action and bundle ID;
- unknown wrapper action;
- missing backup output argument;
- missing restore input argument.

Preserve existing usage text and option parsing.

### InvalidInput — 21

- restore backup source does not exist at the existing precheck.

Do not add canonicalization, ownership, mode, symlink or race checks; TASK-4.6 owns path/workspace hardening.

### HelperUnavailable — 60

- installed `HELPER_TOOL_PATH` is not executable at the existing entry check.

Preserve the current check ordering relative to global option parsing. Do not redesign help/setup ordering in this task.

### TargetUnavailable — 61

- `find_app_executable` cannot find the target in any `do_*` operation.

Do not change target discovery or bundle matching.

### EntitlementFailure — 62

Use for existing operation-level failures caused by:

- entitlement extraction failure after a target is found;
- generated helper entitlement file failure;
- no usable derived Keychain groups in backup/wipe;
- missing entitlement input reported by the resign stage.

Do not change entitlement content, fallback group logic, application-identifier behavior or selected-group behavior.

### WorkspaceFailure — 63

Use for existing explicit failures caused by:

- failure to copy the installed helper into the existing temporary directory;
- missing copied helper binary reported by the resign stage.

Do not change `TEMP_DIR`, cleanup trap, `mkdir`, `cp`, `chmod`, filenames, permissions or path construction beyond selecting the exit code for already-detected failures.

### SigningFailure — 64

Use when `ldid` exists and signing execution returns nonzero.

Preserve current captured/logged `ldid` output behavior. Do not include signing output in the machine result.

### DependencyUnavailable — 65

Use when required `ldid` cannot be found during entitlement extraction or resigning.

The existing optional `plutil` fallback behavior remains unchanged and must not become a hard DependencyUnavailable failure where it is currently warning/fallback-only.

## Wrapper completed and partial behavior

The wrapper propagates recognized direct-helper codes exactly:

```text
0  -> 0
10 -> 10
20 -> 20
21 -> 21
30 -> 30
40 -> 40
50 -> 50
```

Only `0` is completed success.

Code `10` is a nonzero partial outcome. Existing callers that only test zero/nonzero therefore fail closed until TASK-4.8 adds structured partial-result integration.

The existing wrapper `list` short-circuit when no groups are discovered remains `0` and does not invoke the helper. TASK-4.7 owns requested/effective group reporting and any later reconsideration of this behavior.

## Shell boundaries

Do not:

- emit a synthetic TASK-4.1 machine line from the shell;
- parse, decode, validate, remove or reorder helper stdout;
- parse human stderr;
- add timeout or output caps;
- change temporary-directory naming or cleanup;
- change entitlement contents;
- change app/group discovery;
- change helper argv;
- change restore `--overwrite` forwarding;
- change Security behavior.

# Part D — Caller consequences and protection

## Protected callers

Keep byte-identical:

```text
AppDataBackupManager.m
AppDataCleaner.m
WeaponXKeychainBridge/Tweak.m
```

Do not add exact-code switches or result parsers.

Existing zero/nonzero behavior intentionally means:

- completed backup/restore/wipe/list remains success;
- partial direct or wrapped operations become nonzero failure at current callers;
- typed wrapper setup failures remain nonzero failure;
- current Keychain restore remains warning-only at the aggregate Restore policy boundary;
- current Clear records a Keychain component failure for nonzero helper status;
- TASK-4.8 later consumes structured partial facts instead of reducing all nonzero outcomes to one boolean.

This is exit-policy behavior, not manager/cleaner integration.

## TASK-4.1 protocol freeze

Keep byte-identical:

```text
KeychainHelper/PXKeychainHelperResult.h
KeychainHelper/PXKeychainHelperResult.m
```

Preserve exact:

```text
schema version: 1
root keys: 10
fatalError keys: 3
output prefix: PXKEYCHAIN_HELPER_RESULT_V1=
base64/binary-plist framing
privacy exclusions
fixed size/count limits
```

Do not add `exitCode`, wrapper stage, target, groups, paths or messages to the payload.

## Keychain core freeze

Keep byte-identical:

```text
KeychainHelper/KeychainBackupHelper.h
KeychainHelper/KeychainBackupHelper.m
```

Preserve all current:

```text
SecItemCopyMatching
SecItemAdd
SecItemDelete
restore overwrite pre-wipe
warning/error collection
item counts
backup file schema
```

TASK-4.3 through TASK-4.5 own mutation redesign.

# Explicit task boundaries

Do not implement:

- TASK-4.3 removal of broad restore pre-delete;
- TASK-4.4 exact identity for each Keychain class;
- TASK-4.5 per-item update/upsert;
- TASK-4.6 temporary workspace/path hardening;
- TASK-4.7 requested/effective access-group reporting;
- TASK-4.8 machine-result parsing or partial-result manager integration;
- TASK-4.9 backup-file protection policy;
- bridge protocol unification;
- Keychain rollback;
- UI changes;
- manifest changes;
- Phase 5 or Phase 6 work.

# Static gates

Expected implementation scope:

```text
A KeychainHelper/PXKeychainHelperExitCode.h
M KeychainHelper/backup_helper.m
M scripts/keychain_backup.sh
A docs/backup-restore-hardening/reports/TASK-4.2-REPORT.md
```

Required enum counts:

```text
public exit enums:                 1
exit enum values:                 13
direct-helper values:              7
wrapper-only values:               6
numeric duplicates:                0
values outside 0...255:            0
```

Required direct-helper counts:

```text
exit-code header imports:           1
result header imports:              1
semantic finalizers:                1
result emitters:                    1
result-line fprintf sites:          1
fflush(stdout) sites:               1
INVALID literals:                   1
raw return 1/2/3 sites:             0
wrapper-only return constants:      0
```

Required shell counts:

```text
readonly exit constants:           13
normalizer definitions:             1
normalizer operation uses:          4
recognized direct codes:            7
helper-code passthrough mappings:    7
wrapper-only code definitions:       6
machine-result parsers:              0
base64/plist parsers:                 0
```

Required protected diffs:

```text
PXKeychainHelperResult.h/.m:         0
KeychainBackupHelper.h/.m:           0
Makefile:                             0
AppDataBackupManager.h/.m:           0
AppDataCleaner.h/.m:                 0
WeaponXKeychainBridge/Tweak.m:       0
Phase-3 production source:           0
UI source:                            0
```

Required behavior gates:

```text
Completed -> 0
Partial -> 10
argument failure -> 20
restore input failure -> 21
fatal SecurityFramework -> 30
other fatal operation -> 40
protocol/framing failure -> 50
pre-helper wrapper setup -> exact 60...65
recognized helper status -> exact pass-through
unknown helper status -> 40
```

# Validation matrix

The report must include explicit evidence for at least:

## Enum contract

- every exact enum name/value;
- no duplicate values;
- direct/wrapper partition;
- portable exit range;
- no legacy aliases.

## Direct helper

- help -> 0 and no result;
- missing action -> Unknown/Failed + 20;
- unknown action -> Unknown/Failed + 20;
- every known-action missing argument -> selected operation/Failed + 20;
- backup Completed -> 0;
- backup warning-only Partial -> 10;
- backup failed-item Partial -> 10;
- backup error-array-only Partial -> 10;
- restore Completed -> 0;
- restore warning/error/failed Partial -> 10;
- wipe Completed -> 0;
- wipe warning-only Partial -> 10;
- wipe error-only Partial -> 10;
- wipe failed-item Partial -> 10;
- list zero/multiple items -> 0;
- restore FileIO -> 21;
- restore InvalidBackupFile -> 21;
- backup FileIO -> 40;
- SecurityFramework fatal -> 30;
- foreign fatal error -> 40;
- nil error synthetic Unknown -> 40;
- result construction nil -> INVALID + 50;
- mismatched result/exit -> INVALID + 50;
- valid result/exit pair -> exact line + exact code;
- exactly one line per non-help invocation.

## Shell wrapper

- missing helper -> 60;
- malformed wrapper invocation -> 20;
- unknown wrapper action -> 20;
- missing backup/restore file argument -> 20;
- missing restore source -> 21;
- target not found in each operation -> 61;
- ldid unavailable during extraction -> 65;
- entitlement extraction failure -> 62;
- no groups backup/wipe -> 62;
- entitlement generation failure -> 62;
- helper copy failure -> 63;
- missing copied binary in resign -> 63;
- missing entitlement file in resign -> 62;
- ldid signing nonzero -> 64;
- helper direct codes 0/10/20/21/30/40/50 pass unchanged;
- helper legacy/unknown status 1/2/3 -> 40;
- helper 126/127 -> 40;
- helper signal-style status -> 40;
- list no-groups short-circuit remains 0;
- no stdout parser;
- no machine-line rewrite/filter.

## Caller and non-regression

- manager source hash unchanged;
- cleaner source hash unchanged;
- bridge source hash unchanged;
- current callers still only distinguish zero/nonzero;
- partial now fails closed at those callers;
- TASK-4.1 result source/hash/schema unchanged;
- Keychain core source/hash/Security calls unchanged;
- restore pre-wipe unchanged;
- script temp path/cleanup unchanged;
- entitlement content/group selection unchanged;
- Makefile unchanged;
- Phase-3 source unchanged.

# Required report

Create:

```text
docs/backup-restore-hardening/reports/TASK-4.2-REPORT.md
```

The report must include:

1. baseline and exact scope;
2. protected SHA-256/byte-size table;
3. legacy direct-helper exit inventory;
4. legacy shell-wrapper failure inventory;
5. exact public enum and direct/wrapper partition;
6. result-completion to exit mapping;
7. failed-error category mapping;
8. ProtocolFailure precedence;
9. one-finalizer proof;
10. direct-helper terminal-path table;
11. exact shell constant table;
12. wrapper pre-helper mapping table;
13. recognized-child passthrough/normalization proof;
14. partial-result fail-closed caller consequence;
15. zero manager/cleaner/bridge parser integration;
16. TASK-4.1 schema/framing byte identity;
17. Keychain core/Security/pre-wipe byte identity;
18. TASK-4.3 through TASK-4.9 boundary proof;
19. authorized full diff;
20. static-gate table;
21. at least 220 explicit numbered scenario rows;
22. shell syntax/static validation status;
23. whitespace, CRLF, NUL and final-newline audit;
24. build/toolchain status and device risks.

The report must end exactly:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

# Post-commit gates

Run and record:

```text
git show --check --oneline HEAD
git show --stat --oneline HEAD
git diff 1a59e96258651aa9c6aa8d77a1e6debea67ab524..HEAD --check
git diff --name-status 1a59e96258651aa9c6aa8d77a1e6debea67ab524..HEAD
git status --short --untracked-files=all
```

Expected commit manifest:

```text
A KeychainHelper/PXKeychainHelperExitCode.h
M KeychainHelper/backup_helper.m
M scripts/keychain_backup.sh
A docs/backup-restore-hardening/reports/TASK-4.2-REPORT.md
```

Suggested commit:

```text
phase4(task-4.2): define reliable keychain helper exit codes
```

Stop after TASK-4.2. Do not implement TASK-4.3 or any later task.
