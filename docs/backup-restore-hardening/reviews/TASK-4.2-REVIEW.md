# TASK-4.2 Review — Define Reliable Keychain Helper Exit Codes

Implementation commit reviewed: `5c6e70ac4ecd815727c50216c80176d1cf9f80f2`

Production source review: **ACCEPTED**

Final status: **COMPLETED**

TASK-4.3 may open: **YES**

## Reviewed scope

```text
A KeychainHelper/PXKeychainHelperExitCode.h
M KeychainHelper/backup_helper.m
M scripts/keychain_backup.sh
A docs/backup-restore-hardening/reports/TASK-4.2-REPORT.md
```

The implementation commit contains exactly the four authorized files. There is no production diff outside TASK-4.2 scope.

## Public exit taxonomy

`PXKeychainHelperExitCode.h` contains one enum, thirteen values and no class, function, alias, mutable state or compatibility value:

```text
0   Completed
10  Partial
20  InvalidArguments
21  InvalidInput
30  AccessDenied
40  OperationFailed
50  ProtocolFailure
60  HelperUnavailable
61  TargetUnavailable
62  EntitlementFailure
63  WorkspaceFailure
64  SigningFailure
65  DependencyUnavailable
```

The direct-helper range and wrapper-only range remain disjoint.

## Direct helper acceptance

`backup_helper.m` imports the exit-code header exactly once and uses one semantic finalizer for every non-help terminal path.

Static source evidence:

```text
finalizer definitions:                  1
non-help finalizer calls:              16
emitter definitions:                    1
emitter calls outside definition:       1
result-line fprintf sites:              1
fflush(stdout) sites:                   1
INVALID fallback literals:              1
raw direct return 1/2/3:            0/0/0
wrapper-only exit references:            0
```

The finalizer enforces:

```text
Completed -> 0
Partial   -> 10
Failed    -> 20, 21, 30 or 40
```

A nil result, invalid/empty machine line, invalid completion or intended-exit mismatch emits:

```text
PXKEYCHAIN_HELPER_RESULT_V1=INVALID
```

and returns `ProtocolFailure` (`50`). Protocol failure therefore overrides an intended business result.

`--help` remains an explicit exception: it prints current usage, returns `0` and emits no structured result.

## Fatal-error classification

Classification uses only exact operation, `NSError.domain` and `NSError.code` facts.

Accepted mapping:

```text
InvalidArguments / NoAccessGroups -> 20
Restore FileIO                    -> 21
Restore InvalidBackupFile         -> 21
SecurityFramework                 -> 30
Backup FileIO                     -> 40
Unknown                           -> 40
foreign/future domain or code     -> 40
```

No classification depends on `localizedDescription`, warning strings, stderr text or OSStatus text.

Partial results always return `10`, including warning-only, error-only and failed-item cases. A partial Security warning is not incorrectly promoted to fatal AccessDenied.

## Shell-wrapper acceptance

`scripts/keychain_backup.sh` defines all thirteen values as non-exported readonly constants.

It has one normalizer and four operation call sites:

```text
helper executions:        4
normalizer definitions:   1
normalizer calls:         4
machine-result parsers:   0
result-prefix references: 0
```

Recognized direct-helper statuses pass through unchanged:

```text
0, 10, 20, 21, 30, 40, 50
```

Every other child status, including legacy `1/2/3`, launch failures, `126/127`, signal-style statuses and unknown future values, is normalized fail-closed to `40` with a bounded numeric diagnostic.

Pre-helper failure mapping is implemented without expanding filesystem authority:

```text
20 missing/unknown wrapper arguments
21 missing restore source file
60 installed helper unavailable
61 target application unavailable
62 entitlement extraction/generation or unusable groups
63 existing temporary-copy setup failure
64 ldid signing execution failure
65 required ldid unavailable
```

The existing list-with-no-groups short circuit remains `0` without invoking the helper, as explicitly reserved for TASK-4.7.

Both Git Bash syntax checks reported exit zero:

```text
C:\Program Files\Git\bin\bash.exe -n scripts/keychain_backup.sh
C:\Program Files\Git\usr\bin\bash.exe -n scripts/keychain_backup.sh
```

## Caller and protocol boundaries

The following remain byte-identical:

```text
KeychainHelper/PXKeychainHelperResult.h/.m
KeychainHelper/KeychainBackupHelper.h/.m
Makefile
AppDataBackupManager.h/.m
AppDataCleaner.h/.m
WeaponXKeychainBridge/Tweak.m
Phase-1 through Phase-3 production source
Restore infrastructure
UI/controllers
```

No manager, cleaner or bridge code parses the result line or switches on the new exact codes. Current callers remain zero/nonzero consumers, so Partial `10` fails closed until TASK-4.8.

TASK-4.1 protocol remains exact:

```text
schemaVersion: 1
root keys: 10
fatalError keys: 3
binary-plist/base64 framing unchanged
privacy exclusions unchanged
```

## Keychain-core non-regression

Static Security-operation counts remain unchanged:

```text
SecItemCopyMatching: 5 -> 5
SecItemAdd:          1 -> 1
SecItemDelete:       2 -> 2
restore pre-wipe:    1 -> 1
```

TASK-4.2 does not remove the broad restore pre-delete, define item identity, implement upsert, secure the shell workspace or integrate manager partial results.

## Report and build evidence

The implementation report contains 596 explicit numbered scenarios and ends exactly:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

The report records:

- semantic model assertions: PASS;
- Objective-C delimiter/quote balance: PASS;
- Git Bash syntax: PASS;
- protected-file comparison: PASS;
- local Apple SDK/Theos compile/link: not available on this Windows workspace.

Owner continuation is accepted as build-status confirmation. Full target-device testing remains required for actual shell status propagation, ldid categories and Foundation protocol-failure behavior.

## Independent final gates

```text
HEAD:                                      5c6e70ac4ecd815727c50216c80176d1cf9f80f2
git show --check:                         PASS
baseline-to-HEAD diff --check:            PASS
implementation scope:                     PASS
protected production diff:                0
TASK-4.1 result hash mismatches:           0
shell syntax failures:                    0
report scenario rows:                   596
report exact ending:                     PASS
uncommitted production diff:              0
```

## Conclusion

TASK-4.2 establishes a stable fail-closed exit taxonomy while preserving the TASK-4.1 protocol and all Keychain mutation algorithms. TASK-4.3 may now remove the unsafe group/class-wide restore pre-delete without combining that change with exact identity or per-item upsert.
