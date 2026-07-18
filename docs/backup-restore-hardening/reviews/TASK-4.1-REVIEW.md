# TASK-4.1 Review — Add Structured Keychain Helper Result

Implementation commit reviewed: `1a59e96258651aa9c6aa8d77a1e6debea67ab524`

Production source review: **ACCEPTED**

Final status: **COMPLETED**

TASK-4.2 may open: **YES**

## Scope

Exact implementation commit scope:

```text
A KeychainHelper/PXKeychainHelperResult.h
A KeychainHelper/PXKeychainHelperResult.m
M KeychainHelper/backup_helper.m
M Makefile
A docs/backup-restore-hardening/reports/TASK-4.1-REPORT.md
```

No protected production file differs from baseline `02770e21bb1b7c7d691a8ac27c3f0fefabad135b`.

## Public protocol contract

The new result module exports exactly:

- four public constants;
- five operation values with exact numeric values `0...4`;
- three completion values with exact numeric values `1...3`;
- eight construction-error values with exact numeric values `1...8`;
- one subclassing-restricted `NSObject<NSCopying>` result class;
- fourteen readonly properties;
- one public factory;
- unavailable `init` and `new`;
- no public mutation or alternate payload initializer.

Exact exported values are preserved:

```text
schemaVersion = 1
outputPrefix = PXKEYCHAIN_HELPER_RESULT_V1=
errorDomain = com.hydra.projectx.keychain-helper-result
fieldPathKey = fieldPath
```

`copyWithZone:` returns `self`. Equality and hash cover the complete immutable retained state; the additionally compared machine line is a deterministic derivative of the same closed representation and does not widen equality authority.

## Validation and bounded representation

The factory enforces:

- exact operation and completion enums;
- every count at most `1,000,000`;
- subtraction-based overflow-safe proof of `succeeded + failed + skipped <= attempted`;
- Unknown only with Failed;
- Failed only with a fatal `NSError`;
- Completed/Partial with no fatal error;
- Completed with no issue counts;
- Partial with at least one issue count;
- nonempty, lossless, control-free and NUL-free fatal domain;
- exact 255-byte fatal-domain limit;
- exact 16 KiB binary-plist limit;
- exact 24 KiB base64 limit;
- exact 25 KiB complete-line limit.

The property-list root has exactly ten keys and nested `fatalError` has exactly three keys. Serialization has one binary-plist site and one base64-encoder site. The payload is decoded and read back as an immutable plist, compared with the retained state and then published.

No bundle identifier, access group, item identity, service, account, label, secret, file path, command line, entitlement or human diagnostic is retained in the machine result. Construction errors use bounded fixed descriptions and field paths only.

## CLI framing and terminal coverage

`backup_helper.m` imports the result header once and uses:

```text
one structured-result factory call family
one result emitter definition
one result-line fprintf site
one fflush(stdout) site
one INVALID fallback literal
```

The emitter appends exactly one newline and writes no payload to stderr.

All non-help terminal paths emit one machine line before returning:

- missing action;
- unknown action;
- every missing required argument;
- backup critical/completed/partial;
- restore critical/completed/partial;
- wipe critical/completed/partial;
- list missing groups/completed;
- unreachable default fallback.

`--help` remains exit zero and emits no machine line.

Known-action argument failures preserve the selected operation. Missing or unknown action uses Unknown. Nil operation results use Failed and preserve only fatal domain/code. Existing result objects derive Partial from any failed item, warning or error; otherwise Completed. List uses item count for attempted and succeeded.

## Exit-code freeze

TASK-4.1 does not make process exit depend on completion:

```text
help                              0
missing/unknown arguments         1
backup nil result                 2
restore nil result                2
wipe nil result                   2
wipe failures or warnings         2
backup result object              0
restore result object             0
list success                      0
```

The legacy wipe errors-only path remains exit zero while its machine completion is Partial. This inconsistency is intentionally left for TASK-4.2.

## Protected behavior

Byte-identical protected sources include:

- `KeychainHelper/KeychainBackupHelper.h/.m`;
- `scripts/keychain_backup.sh`;
- `AppDataBackupManager.h/.m`;
- `AppDataCleaner.h/.m`;
- `WeaponXKeychainBridge/Tweak.m`;
- Keychain controllers/hooks/UUID manager;
- Phase-1 through Phase-3 production source;
- Restore plan/result/staging/transaction source.

Independent occurrence comparison confirms:

```text
SecItemCopyMatching: 5 -> 5
SecItemAdd:          1 -> 1
SecItemDelete:       2 -> 2
restore overwrite:   1 -> 1
pre-wipe warning:    1 -> 1
```

The script passes helper stdout/stderr and exit status unchanged. Manager, cleaner and bridge add no parser for the new result. Broad restore pre-delete, item identity, upsert, temporary workspace, requested/effective groups and backup protection remain untouched.

## Build and report evidence

The report contains 312 explicit numbered scenario rows and ends exactly:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

Report evidence includes a 500,168-assertion invariant/framing model. The implementation host had no clang, Theos or make, so no local linked iOS artifact was produced. The owner's continuation request is accepted as build-status confirmation; GitHub Actions/device execution remains authoritative for target SDK linkage and runtime stdout ordering.

## Independent gates

```text
HEAD:                                      1a59e96258651aa9c6aa8d77a1e6debea67ab524
implementation files:                     5 exact
git show --check:                         PASS
baseline-to-HEAD diff --check:            PASS
working-tree diff --check:                PASS
protected named production diff:          0
Phase-3 production diff:                  0
public exports:                            4
operation enum values:                    5
completion enum values:                   3
construction error codes:                 8
readonly properties:                     14
public factories:                         1
binary serializer sites:                  1
base64 encoder sites:                     1
result imports:                            1
emitter definitions:                      1
result-line fprintf sites:                1
fflush(stdout) sites:                     1
INVALID fallback literals:                1
Makefile result-source entries:           1
report scenario rows:                   312
new result/report trailing whitespace:    0
NUL bytes in implementation/report:       0
uncommitted production diff:              0
```

Existing trailing spaces in baseline-owned CRLF portions of `backup_helper.m` and `Makefile` were not introduced by TASK-4.1; all committed added/changed lines pass `git show --check` and cumulative diff checks.

## Verdict

TASK-4.1 establishes a bounded immutable machine protocol without changing Keychain item algorithms or legacy process-exit behavior.

TASK-4.1 is **COMPLETED**.

TASK-4.2 may open. TASK-4.3 and later remain locked until TASK-4.2 acceptance.
