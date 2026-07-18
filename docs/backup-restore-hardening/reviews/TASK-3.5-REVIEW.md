# TASK-3.5 Review

Implementation commit reviewed: `5366c503a3946faafc7a107c4e411255ece3e0f3`

Production source review: **ACCEPTED**

Final status: **COMPLETED**

TASK-3.6 may open: **YES**

## Scope

The implementation commit contains exactly:

```text
M AppDataBackupManager.m
A PXBackupArtifactPolicy.h
A PXBackupArtifactPolicy.m
M PXBackupArtifactWriter.h
M PXBackupArtifactWriter.m
A docs/backup-restore-hardening/reports/TASK-3.5-REPORT.md
```

No protected production file changed.

## Accepted policy model

The public model contains exactly:

```text
artifact kinds:        8
requirements:          2
failure dispositions:  3
empty-file policies:   2
public factories:      1
size-policy methods:   1
public initializers:   0
NSCopying classes:     1
```

The canonical matrix is implemented exactly:

| Kind | Requirement | Failure disposition | Empty file |
|---|---|---|---|
| ApplicationData | Required | AbortBackup | Reject |
| AppGroup | Optional | WarnAndContinue | Reject |
| ProfileAppData | Optional | WarnAndContinue | Reject |
| GlobalSafari | Optional | WarnAndContinue | Reject |
| SystemGlobal | Optional | WarnAndContinue | Reject |
| SharedSystemDatabase | Optional | ContinueWithoutWarning | Allow |
| Preferences | Optional | ContinueWithoutWarning | Reject |
| Keychain | Optional | ContinueWithoutWarning | Reject |

Unknown kinds return `nil`. The model is immutable, subclassing-restricted, value-equal across all four fields and returns itself from `copyWithZone:`.

## Writer integration

`PXBackupArtifactWriterErrorPolicyRejected = 17` was added without renumbering the accepted sixteen codes.

The policy-aware writer method is the only artifact method. The policy-free method no longer exists.

The writer:

1. requires an exact `PXBackupArtifactPolicy` runtime object;
2. retains it in `PXVerifiedBackupArtifact`;
3. performs the complete stable streaming read and digest;
4. calls `acceptsFileSize:`;
5. rejects disallowed output before payload `fsync`, `renameat`, record construction, accepted-path insertion or artifact-count increment;
6. reports generic code 17 at `$.artifact.policy`;
7. performs bounded pre-rename cleanup.

The policy gate appears before all finalization boundaries:

```text
policy gate < payload fsync < renameat < record construction < artifactCount increment
```

The v3 `manifestRepresentation` remains exactly `name`, `path`, `size` and `sha256`; policy metadata is not serialized.

## Manager integration

Eight canonical policies are built immediately after writer creation and initial writer validation, before output directories, debug files, process kill or producer execution.

Exact counts:

```text
policyForKind calls:            8
canonical policy arrays:        1
policy-aware writer sites:      8
policy arguments:               8
failure helper definitions:     1
failure helper calls:           8
policy-audit definitions:       1
policy-audit calls:             1
```

Every semantic producer uses the correct policy:

```text
data.tar.gz             -> ApplicationData
App Group loop          -> AppGroup
profile_appdata.tar.gz  -> ProfileAppData
global_safari.tar.gz    -> GlobalSafari
system-global loop      -> SystemGlobal
shared DB loop          -> SharedSystemDatabase
Preferences             -> Preferences
keychain.plist           -> Keychain
```

ApplicationData remains the only hard-failure artifact and retains manager code 105. App Group, profile, Safari and system-global preserve their exact warnings. Preferences and Keychain add no generic writer warning. Shared DB per-file failure remains silent and uses the existing aggregate warning.

## Pre-manifest audit

The audit runs after the final writer identity validation and before artifact dictionary conversion, total-size accumulation and manifest writing.

It proves:

- eight canonical policies and their exact matrix;
- writer artifact count equals the retained record count;
- count is from 1 through 4096;
- every record retains the exact canonical policy;
- every retained size is accepted by that policy;
- kinds are in nondecreasing canonical order;
- exactly one ApplicationData record;
- exactly one required record total;
- the required record is first;
- singleton optional kinds appear at most once;
- all non-ApplicationData records are optional.

The audit does not reorder, repair, drop or synthesize records.

## Non-regression

Accepted counts remain:

```text
lock factory:           1
lock validations:       4
workspace factory:      1
workspace validations:  3
writer factory:         1
writer validations:     3
semantic producer sites: 8
artifact renameat sites: 1
final Backup publication: 0
manifestVersion:         3
```

The following remain byte-identical or have zero diff:

- `PXBackupBundleLock.h/.m`;
- `PXBackupPublicationWorkspace.h/.m`;
- `AppDataBackupManager.h`;
- Restore transaction/staging/planning sources;
- manifest/artifact/archive Restore validators;
- UI/controller sources;
- Keychain helper/bridge/script sources;
- `CommandRunner.h/.m`;
- `Makefile`.

TASK-3.4 request-versus-inclusion behavior remains intact.

## Independent gates

```text
git show --check:                    PASS
baseline diff --check:               PASS
protected production diff:           0
artifact kinds:                       8
writer error codes:                  17
policy-free writer methods:           0
policy rejection sites:               1
policy-aware manager sites:           8
failure-policy helper calls:          8
pre-manifest audit calls:             1
legacy artifact helper tokens:        0
manifest policy fields:               0
report scenario rows:               295
new trailing whitespace:              0
new NUL bytes:                        0
```

The report records strict Objective-C frontend passes. This workspace does not contain a linked Theos/iOS artifact or device fault-injection fixture; owner continuation is accepted as build-status confirmation.

## Next-task boundary

TASK-3.6 may introduce manifest schema v4 and version-aware structural validation.

TASK-3.6 must not implement atomic manifest writing, final Backup publication, centralized partial cleanup or stale-workspace cleanup. Those remain TASK-3.7 through TASK-3.10.
