# TASK-4.1 — Add Structured Keychain Helper Result

- Status: READY
- Phase: 4 — Keychain Safety
- Baseline: `02770e21bb1b7c7d691a8ac27c3f0fefabad135b`
- Depends on: Phase 3 completed, including TASK-3.10 and TASK-3.10A
- Next task: TASK-4.2 remains locked

## Objective

Introduce one immutable, bounded and machine-readable result envelope at the `backup_helper` CLI boundary.

TASK-4.1 establishes only the result protocol. It must not change Keychain item algorithms, business success policy, helper exit codes, shell-wrapper behavior, manager behavior, bridge behavior, temporary workspace handling, access-group selection, restore pre-delete behavior or per-item mutation semantics.

The current helper already produces an internal mutable `PXKeychainBackupResult` containing counts and arrays of human-readable warnings/errors. The CLI currently converts that object into human stdout/stderr lines and process exit codes. TASK-4.1 adds a separate immutable protocol object that snapshots only bounded operational facts and emits one uniquely prefixed machine-readable line.

## Mandatory reading

Read before editing:

```text
docs/backup-restore-hardening/reviews/TASK-3.10A-REVIEW.md
docs/backup-restore-hardening/ROADMAP.md
KeychainHelper/KeychainBackupHelper.h
KeychainHelper/KeychainBackupHelper.m
KeychainHelper/backup_helper.m
scripts/keychain_backup.sh
Makefile
AppDataBackupManager.m
WeaponXKeychainBridge/Tweak.m
```

The script, manager and bridge are audit inputs only and are protected in this task.

## Authorized production scope

Only create or modify:

```text
A KeychainHelper/PXKeychainHelperResult.h
A KeychainHelper/PXKeychainHelperResult.m
M KeychainHelper/backup_helper.m
M Makefile
```

Create the report:

```text
A docs/backup-restore-hardening/reports/TASK-4.1-REPORT.md
```

The implementation commit must contain exactly these five files.

## Protected files

Do not modify:

```text
KeychainHelper/KeychainBackupHelper.h
KeychainHelper/KeychainBackupHelper.m
scripts/keychain_backup.sh
AppDataBackupManager.h
AppDataBackupManager.m
WeaponXKeychainBridge/Tweak.m
WeaponXKeychainBridge.plist
keychain_base_ent.plist
BackupKeychainGroupsViewController.h/.m
KeychainGroupsViewController.h/.m
ProjectXTweak/KeychainHooks.x
common/KeychainUUIDManager.h/.m
all Backup/Restore Phase-1 through Phase-3 infrastructure
all Restore plan/result/transaction/staging source
all UI/controller source outside the protected files listed above
all coordinator documentation other than the required TASK-4.1 report
```

Do not stage, revert, delete, reformat or rewrite coordinator-owned modified/untracked documentation.

## Baseline evidence

Before editing, record in the report:

```text
git status --short --untracked-files=all
git rev-parse HEAD
git log -8 --oneline
git diff --check
```

Record SHA-256 and byte size before/after for every protected production file named above and for all Phase-3 infrastructure.

# Part A — Immutable result protocol

## Public exports

Create `KeychainHelper/PXKeychainHelperResult.h` with exactly these exports:

```objc
FOUNDATION_EXPORT NSInteger const PXKeychainHelperResultSchemaVersion;
FOUNDATION_EXPORT NSString * const PXKeychainHelperResultOutputPrefix;
FOUNDATION_EXPORT NSErrorDomain const PXKeychainHelperResultErrorDomain;
FOUNDATION_EXPORT NSString * const PXKeychainHelperResultErrorFieldPathKey;
```

Exact values:

```text
schema version: 1
output prefix:  PXKEYCHAIN_HELPER_RESULT_V1=
error domain:   com.hydra.projectx.keychain-helper-result
field-path key: fieldPath
```

## Operation enum

Create exactly:

```objc
typedef NS_ENUM(NSInteger, PXKeychainHelperOperation) {
    PXKeychainHelperOperationUnknown = 0,
    PXKeychainHelperOperationBackup = 1,
    PXKeychainHelperOperationRestore = 2,
    PXKeychainHelperOperationWipe = 3,
    PXKeychainHelperOperationList = 4,
};
```

Canonical serialized strings:

```text
unknown
backup
restore
wipe
list
```

`Unknown` is permitted only for an argument/dispatch failure before a valid action is selected.

## Completion enum

Create exactly:

```objc
typedef NS_ENUM(NSInteger, PXKeychainHelperCompletion) {
    PXKeychainHelperCompletionFailed = 1,
    PXKeychainHelperCompletionCompleted = 2,
    PXKeychainHelperCompletionPartial = 3,
};
```

Canonical serialized strings:

```text
failed
completed
partial
```

These values report observed operation facts. They do not define process exit codes; TASK-4.2 owns exit-code policy.

## Error enum

Create exactly eight result-construction error codes:

```objc
typedef NS_ERROR_ENUM(PXKeychainHelperResultErrorDomain,
                      PXKeychainHelperResultErrorCode) {
    PXKeychainHelperResultErrorInvalidInput = 1,
    PXKeychainHelperResultErrorInvalidOperation = 2,
    PXKeychainHelperResultErrorInvalidCompletion = 3,
    PXKeychainHelperResultErrorInvalidCounts = 4,
    PXKeychainHelperResultErrorInvalidFatalError = 5,
    PXKeychainHelperResultErrorLimitExceeded = 6,
    PXKeychainHelperResultErrorSerializationFailed = 7,
    PXKeychainHelperResultErrorInternalInvariantFailed = 8,
};
```

Do not renumber or add gaps.

## Public class

Create one subclassing-restricted immutable class:

```objc
__attribute__((objc_subclassing_restricted))
@interface PXKeychainHelperResult : NSObject <NSCopying>
```

Readonly properties:

```objc
@property (nonatomic, readonly) NSInteger schemaVersion;
@property (nonatomic, readonly) PXKeychainHelperOperation operation;
@property (nonatomic, readonly) PXKeychainHelperCompletion completion;
@property (nonatomic, readonly) NSUInteger attemptedCount;
@property (nonatomic, readonly) NSUInteger succeededCount;
@property (nonatomic, readonly) NSUInteger failedCount;
@property (nonatomic, readonly) NSUInteger skippedCount;
@property (nonatomic, readonly) NSUInteger warningCount;
@property (nonatomic, readonly) NSUInteger errorCount;
@property (nonatomic, readonly) BOOL fatalErrorPresent;
@property (nonatomic, copy, readonly) NSString *fatalErrorDomain;
@property (nonatomic, readonly) NSInteger fatalErrorCode;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, id> *propertyListRepresentation;
@property (nonatomic, copy, readonly) NSString *machineReadableLine;
```

Factory only:

```objc
+ (nullable instancetype)resultWithOperation:(PXKeychainHelperOperation)operation
                                  completion:(PXKeychainHelperCompletion)completion
                              attemptedCount:(NSUInteger)attemptedCount
                              succeededCount:(NSUInteger)succeededCount
                                 failedCount:(NSUInteger)failedCount
                                skippedCount:(NSUInteger)skippedCount
                                warningCount:(NSUInteger)warningCount
                                  errorCount:(NSUInteger)errorCount
                                  fatalError:(NSError * _Nullable)fatalError
                                       error:(NSError * _Nullable * _Nullable)error;
```

Unavailable:

```objc
- init
+ new
```

No public mutation methods, serialization bypass, alternate representation factory or raw-payload initializer.

`copyWithZone:` returns `self`.

Equality and hash use every public property except the derived `machineReadableLine`; equivalently they may use the complete immutable property-list representation.

## Fixed bounds

Use exact fixed limits:

```text
maximum value for each count:       1,000,000
maximum fatal-error domain UTF-8:         255 bytes
maximum binary plist payload:          16 KiB
maximum base64 payload:                24 KiB
maximum complete output line:          25 KiB
```

All addition and conversion arithmetic must be overflow-safe.

## Input validation

Require:

- operation is one exact enum value from 0 through 4;
- completion is one exact enum value from 1 through 3;
- every count is within the fixed maximum;
- `succeededCount + failedCount + skippedCount <= attemptedCount` without overflow;
- `Unknown` operation requires `Failed` completion;
- `Failed` completion requires a nonnil exact `NSError`;
- `Completed` and `Partial` require `fatalError == nil`;
- `Completed` requires `failedCount == 0`, `skippedCount == 0`, `warningCount == 0` and `errorCount == 0`;
- `Partial` requires at least one of `failedCount`, `skippedCount`, `warningCount` or `errorCount` to be nonzero;
- a fatal error requires a nonempty, lossless, control-free, NUL-free domain within 255 UTF-8 bytes;
- no trimming, lowercasing or repair of fatal-error domains;
- no `localizedDescription`, `userInfo`, underlying error or path is retained.

The result contains no bundle identifier, access group, item class, service, account, label, secret value, file path, command line, entitlement or human diagnostic message.

## Exact property-list representation

The representation has exactly ten root keys:

```text
schemaVersion
operation
completion
attemptedCount
succeededCount
failedCount
skippedCount
warningCount
errorCount
fatalError
```

`fatalError` has exactly three keys:

```text
present
domain
code
```

No-fatal-error representation:

```text
present = false
domain = ""
code = 0
```

Fatal-error representation:

```text
present = true
domain = exact NSError.domain
code = exact NSError.code
```

The graph must contain only immutable Foundation property-list primitives. Deep-copy it into an immutable snapshot before publication.

No unknown keys, optional keys, item arrays, warning strings, error strings, paths, groups or arbitrary metadata.

## Machine-readable line

Serialize only `propertyListRepresentation` as:

```text
NSPropertyListBinaryFormat_v1_0
```

Base64 encode with no line breaks.

Construct exactly:

```text
PXKEYCHAIN_HELPER_RESULT_V1=<base64 binary plist>
```

`machineReadableLine` contains no trailing newline. The CLI emitter adds the one newline.

Require:

- binary plist size from 1 through 16 KiB;
- base64 payload from 1 through 24 KiB;
- complete UTF-8 line from 1 through 25 KiB;
- prefix appears exactly once at byte zero;
- decoded graph deep-equals the retained representation;
- decoded schema version and all values exactly match retained properties.

Construction failure returns nil with bounded `PXKeychainHelperResultErrorDomain` error. Error text must not include raw NSError userInfo, paths, access groups, item metadata or serialized payload.

## Pure implementation

`PXKeychainHelperResult.m` may import only:

```text
PXKeychainHelperResult.h
Foundation/CoreFoundation headers required for exact type checks
```

It must not import or reference:

```text
Security.framework
KeychainBackupHelper
AppDataBackupManager
WeaponXKeychainBridge
CommandRunner
NSUserDefaults
UIKit
filesystem APIs
shell/process APIs
dispatch
logging
```

No global mutable state.

# Part B — CLI emission

## Existing behavior is the baseline

`KeychainHelper/backup_helper.m` remains the only current caller of `KeychainBackupHelper` APIs.

Preserve:

- existing argument names and parsing;
- existing human stdout/stderr messages and their relative order;
- existing backup/restore/wipe/list Security operations;
- existing internal `PXKeychainBackupResult` use;
- existing warning/error loops;
- existing list item formatting;
- all existing process exit codes and branch decisions;
- `--help` behavior.

TASK-4.1 adds a machine-readable result line; it does not redefine success.

## Import and operation mapping

Import exactly once:

```objc
#import "PXKeychainHelperResult.h"
```

Map CLI actions exactly:

```text
missing/unknown action -> Unknown
backup                 -> Backup
restore                -> Restore
wipe                   -> Wipe
list                   -> List
```

## Completion derivation

For backup, restore and wipe:

```text
KeychainBackupHelper returned nil:
  Failed

result returned and any of the following is nonzero:
  itemsFailed
  warnings.count
  errors.count
  -> Partial

result returned and all values above are zero:
  Completed
```

Counts:

```text
attemptedCount = result.itemsProcessed or 0
succeededCount = result.itemsSucceeded or 0
failedCount = result.itemsFailed or 0
skippedCount = 0
warningCount = result.warnings.count or 0
errorCount = result.errors.count or 0
```

For list:

```text
operation = List
completion = Completed
attemptedCount = items.count
succeededCount = items.count
failedCount = 0
skippedCount = 0
warningCount = 0
errorCount = 0
fatalError = nil
```

For missing arguments, unknown action or a nil operation result:

- completion is Failed;
- create a bounded synthetic NSError when the existing branch has no NSError;
- synthetic domain is `PXKeychainBackupErrorDomain`;
- synthetic code reuses the existing argument/operation error category only for the result envelope;
- do not alter the process exit code;
- do not include the human message in the machine representation.

## Exactly one emitter

Create exactly one file-local emission helper that:

1. accepts a valid `PXKeychainHelperResult`;
2. writes exactly one line to stdout using the exported prefix representation;
3. appends exactly one `\n`;
4. calls `fflush(stdout)`;
5. writes no result data to stderr;
6. logs no payload, path, group or item metadata.

Expected successful output form:

```text
PXKEYCHAIN_HELPER_RESULT_V1=<base64>
```

If result construction unexpectedly fails, emit exactly:

```text
PXKEYCHAIN_HELPER_RESULT_V1=INVALID
```

This fallback is a protocol-failure token, not a valid result. Do not serialize the construction NSError or change the legacy process exit code.

Required emitter counts:

```text
emitter definitions:             1
fprintf result-line sites:       1
fflush(stdout) sites:            1
INVALID fallback literals:       1
```

## Terminal-path coverage

Every non-help invocation must emit exactly one prefixed result line before returning from `main`, including:

- missing action;
- unknown action;
- backup missing file;
- backup missing groups;
- backup critical failure;
- backup completed/partial result;
- restore missing file;
- restore critical failure;
- restore completed/partial result;
- wipe missing groups;
- wipe critical failure;
- wipe completed/partial result;
- list missing groups;
- list completed result.

`--help` continues to print usage and return zero without a structured result line.

Refactor early returns only as necessary to guarantee this coverage. Do not change their numeric return values.

## Exit-code freeze

Preserve exact current exit behavior:

```text
help:                              0
missing/unknown arguments:         1
backup nil result:                 2
restore nil result:                2
wipe nil result:                   2
wipe result with failures/warnings:2
backup result object:              0
restore result object:             0
list success:                      0
```

The existing documented access-denied code remains untouched. TASK-4.2 owns reliable exit-code redesign.

Do not make process exit depend on the new completion enum.

# Part C — Build integration

Modify `Makefile` only to add exactly once:

```text
KeychainHelper/PXKeychainHelperResult.m
```

to `backup_helper_FILES`.

Do not change:

- tool name;
- install path;
- frameworks;
- codesign flags;
- helper script installation;
- bridge target;
- any other target/source list;
- compiler/linker flags.

# Script and caller compatibility

`scripts/keychain_backup.sh` remains byte-identical. It already invokes the helper without filtering helper stdout, so the prefixed line passes through naturally.

`AppDataBackupManager.m` remains byte-identical and continues to use exit code, output file presence and existing warnings exactly as before. It does not parse the result in TASK-4.1.

`WeaponXKeychainBridge/Tweak.m` remains byte-identical. Bridge result unification is not part of this task.

# Non-regression requirements

Keep byte-identical:

```text
KeychainHelper/KeychainBackupHelper.h
KeychainHelper/KeychainBackupHelper.m
scripts/keychain_backup.sh
AppDataBackupManager.h/.m
WeaponXKeychainBridge/Tweak.m
keychain_base_ent.plist
all Backup/Restore Phase-1 through Phase-3 source
Restore plan/result/transaction/staging source
UI/controllers
```

Preserve exact current occurrences of:

```text
SecItemCopyMatching
SecItemAdd
SecItemDelete
restore overwrite pre-wipe
helper temporary directory
entitlement extraction/resigning
selected access-group handling
human warning/error output
```

# Explicit task boundaries

Do not implement:

- TASK-4.2 reliable exit-code policy;
- TASK-4.3 removal of broad restore pre-delete;
- TASK-4.4 exact per-class item identity;
- TASK-4.5 per-item update/upsert;
- TASK-4.6 secure helper temporary workspace/path validation;
- TASK-4.7 requested/effective access-group reporting;
- TASK-4.8 manager or bridge parsing/integration;
- TASK-4.9 backup-file protection policy;
- Keychain item rollback;
- manifest schema changes;
- Backup/Restore UI changes;
- script rewrite;
- bridge protocol changes;
- Phase 5 or Phase 6 work.

The new result must not contain requested or effective access groups; TASK-4.7 owns those facts.

# Static gates

Expected implementation scope:

```text
A KeychainHelper/PXKeychainHelperResult.h
A KeychainHelper/PXKeychainHelperResult.m
M KeychainHelper/backup_helper.m
M Makefile
A docs/backup-restore-hardening/reports/TASK-4.1-REPORT.md
```

Required public-result counts:

```text
exports:                         4
operation enum values:           5
completion enum values:          3
error codes:                     8
result classes:                  1
readonly properties:            14
public factories:                1
public initializers:             0
public mutation methods:         0
```

Required representation counts:

```text
root keys:                      10
fatalError keys:                3
binary-plist serializer sites:  1
base64 encoder sites:           1
output-prefix definitions:      1
```

Required CLI counts:

```text
result imports:                  1
result factory call families:    1 centralized helper or exact equivalent
emitter definitions:             1
result-line fprintf sites:       1
fflush(stdout) sites:            1
INVALID fallback literals:       1
structured output prefixes:      1 exported definition plus emission use
```

Required protected-diff counts:

```text
KeychainBackupHelper.h/.m diff:  0
script diff:                      0
manager diff:                     0
bridge diff:                      0
Phase-3 production diff:          0
UI diff:                          0
```

Required behavior counts:

```text
existing SecItem operation diff:       0
existing exit-code branch values:      unchanged
manager result parsers:                0
script result parsers:                 0
bridge result parsers:                 0
requested/effective-group fields:      0
item identity fields:                  0
file/path fields in result:            0
human warning/error message fields:    0
```

# Validation matrix

The report must include explicit evidence for at least:

## Result construction

- every operation enum;
- every completion enum;
- unknown + failed valid;
- unknown + completed/partial rejected;
- failed without fatal NSError rejected;
- completed/partial with fatal NSError rejected;
- completed with any issue count rejected;
- partial without any issue rejected;
- partial from failed items;
- partial from warning count only;
- partial from error count only;
- count sum exact boundary;
- count sum overflow attempt;
- each count at one million;
- each count above one million;
- fatal domain empty, control, NUL, invalid/lossy UTF-8, oversized;
- fatal negative/positive/zero codes;
- no-fatal exact empty representation;
- deep immutable snapshot;
- copy/equality/hash;
- binary-plist read-back equality;
- base64 round trip;
- line prefix and fixed bounds.

## CLI terminal paths

- help has no line and exit zero;
- missing action;
- unknown action;
- every missing required argument;
- backup nil result;
- backup completed;
- backup partial by warning;
- backup partial by failed count;
- restore nil result;
- restore completed;
- restore partial;
- wipe nil result;
- wipe completed;
- wipe partial with legacy exit two;
- list zero items;
- list multiple items;
- result construction fallback emits `INVALID`;
- exactly one line per non-help invocation;
- existing human log order preserved;
- no result line on stderr;
- no item metadata/path/group in decoded payload.

## Non-regression

- helper core source hashes unchanged;
- script hash unchanged;
- manager hash unchanged;
- bridge hash unchanged;
- Makefile only adds one helper source;
- exit codes unchanged;
- broad restore pre-wipe unchanged;
- Security calls unchanged;
- access-group behavior unchanged;
- Phase-3 source hashes unchanged.

# Required report

Create:

```text
docs/backup-restore-hardening/reports/TASK-4.1-REPORT.md
```

The report must include:

1. baseline and exact scope;
2. protected SHA-256/byte-size table;
3. old mutable-result and CLI-output inventory;
4. exact public API and enums;
5. immutable result invariants;
6. exact ten-key representation;
7. privacy exclusions;
8. binary plist/base64 framing;
9. output bounds and read-back proof;
10. completion derivation table;
11. terminal-path emission inventory;
12. exact exit-code preservation table;
13. script passthrough proof;
14. manager/bridge zero integration proof;
15. Makefile one-line integration;
16. TASK-4.2 through TASK-4.9 boundary proof;
17. authorized full diff;
18. static-gate table;
19. at least 180 explicit numbered scenario rows;
20. whitespace, CRLF, NUL and final-newline audit;
21. build/toolchain status and remaining device risks.

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
git diff 02770e21bb1b7c7d691a8ac27c3f0fefabad135b..HEAD --check
git diff --name-status 02770e21bb1b7c7d691a8ac27c3f0fefabad135b..HEAD
git status --short --untracked-files=all
```

Suggested commit:

```text
phase4(task-4.1): add structured keychain helper result
```

Stop after TASK-4.1. Do not implement TASK-4.2 or any later task.
