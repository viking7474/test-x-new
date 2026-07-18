# TASK-4.3 Review

Implementation commit reviewed: `4c7000289186a4d7cb3772bc7c4b80b24ab4c3f1`

Production source review: **ACCEPTED**

Final status: **COMPLETED**

TASK-4.4 may open: **YES**

## Scope

The implementation commit contains exactly:

```text
M KeychainHelper/KeychainBackupHelper.h
M KeychainHelper/KeychainBackupHelper.m
M KeychainHelper/backup_helper.m
A docs/backup-restore-hardening/reports/TASK-4.3-REPORT.md
M scripts/keychain_backup.sh
```

No production file outside the authorized TASK-4.3 scope changed.

## Build signal

The owner's continuation is accepted as the build-status confirmation for this gate.

The report records that full Objective-C/Theos compile and link were not available on the Windows review host. Git Bash syntax checks passed. Apple SDK compilation, packaging and Security.framework behavior across actual device classes remain CI/device gates.

## Broad restore pre-delete removal

The complete overwrite-time group/class wipe block was removed from `restoreKeychainFromFile:overwrite:error:`.

The restore method now contains:

```text
SecItemCopyMatching: 0
SecItemAdd:          1
SecItemDelete:       0
SecItemUpdate:       0
```

The removed authority included:

```text
backup[@"accessGroups"] deletion input
class aggregation from _secClass
access-group/class nested deletion loops
kSecAttrSynchronizableAny delete query
restore-time SecItemDelete
Pre-wipe failed warnings
comment claiming group-wide pre-wipe had completed
```

No alternate wipe selector, dynamic selector, shell path, bridge path, update call or per-item replacement path was introduced.

## Repository Security authority

The accepted core source inventory is:

```text
SecItemCopyMatching: 5
SecItemAdd:          1
SecItemDelete:       1
SecItemUpdate:       0
```

The sole remaining core `SecItemDelete` is inside the explicit public wipe operation:

```text
+wipeKeychainForAccessGroups:itemClasses:error:
```

Explicit wipe behavior, count-before-delete behavior, group/class iteration and warning accounting remain unchanged.

## Duplicate preservation

`errSecDuplicateItem` is now handled identically as a preserved target item regardless of overwrite request state.

For every duplicate:

```text
existing target item: preserved
SecItemDelete:        not called
SecItemUpdate:        not called
itemsProcessed:       +1 through existing loop
itemsSucceeded:       +0
itemsFailed:          +1
warnings:             +1
errors:               +0
completion:           Partial
exit code:            10
```

Exact non-overwrite warning:

```text
Item already exists; existing item was preserved: %@
```

Exact overwrite-request warning:

```text
Overwrite requested but existing item was preserved pending safe per-item replacement: %@
```

Both warnings substitute only `kSecAttrAccount` or `unknown`. No service, group, class, path or secret value was added to the duplicate diagnostic.

The old conditional form is absent:

```text
errSecDuplicateItem && !overwrite
```

## Overwrite compatibility behavior

The public selector and `overwrite:(BOOL)overwrite` parameter remain unchanged.

`overwrite == YES` now means only that replacement was requested. It does not authorize deletion, update, alternate mutation or a blanket warning.

Consequently:

```text
all items new + overwrite NO:  Completed / 0
all items new + overwrite YES: Completed / 0
one or more duplicates:        Partial / 10
nonduplicate add failures:     Partial / 10
critical file/plist failures:  existing TASK-4.2 mapping
protocol failure:              50
```

## Documentation and CLI text

The public header now documents the transitional overwrite contract without changing selector, nullability, enums or result API.

Direct helper help text is exactly:

```text
--overwrite         For restore: request replacement; existing duplicates are preserved
```

Direct helper verbose text is exactly:

```text
Starting keychain restore (overwrite requested: %@)...
```

Wrapper help text is exactly:

```text
--overwrite   For restore: request replacement; existing duplicates are preserved
```

Argument parsing and wrapper forwarding of `--overwrite` remain unchanged.

## TASK-4.1 and TASK-4.2 non-regression

The following are byte-identical to baseline:

```text
KeychainHelper/PXKeychainHelperResult.h
KeychainHelper/PXKeychainHelperResult.m
KeychainHelper/PXKeychainHelperExitCode.h
Makefile
```

Static protocol/exit gates remain:

```text
structured finalizer definitions: 1
non-help finalizer calls:         16
structured emitter definitions:    1
result-line fprintf sites:         1
fflush(stdout) sites:              1
shell readonly exit constants:    13
shell normalizer definitions:      1
shell normalizer calls:            4
```

No machine-result parser or exact exit-code switch was added to current callers.

## Protected caller and infrastructure boundaries

The following are byte-identical:

```text
AppDataBackupManager.h/.m
AppDataCleaner.h/.m
WeaponXKeychainBridge/Tweak.m
Phase-1 through Phase-3 infrastructure
Restore transaction infrastructure
UI/controllers
```

Current manager/cleaner behavior remains zero/nonzero based. Partial `10` therefore remains fail-closed until TASK-4.8.

## Later-task boundary

TASK-4.3 did not implement:

```text
class-specific identity
preflight duplicate lookup
SecItemUpdate
per-item delete/add replacement
rollback
backup schema migration
secure helper workspace/path validation
requested/effective access-group reporting
manager result parsing
backup-file protection
```

Exact identity belongs to TASK-4.4. Per-item upsert belongs to TASK-4.5.

## Independent gates

```text
HEAD:                                    4c7000289186a4d7cb3772bc7c4b80b24ab4c3f1
git show --check:                        PASS
baseline-to-HEAD diff --check:           PASS
working-tree diff --check:               PASS
implementation scope:                    PASS
restore SecItemDelete sites:                0
restore SecItemUpdate sites:                0
restore SecItemAdd sites:                   1
core SecItemDelete sites:                   1
core SecItemUpdate sites:                   0
exact duplicate warning strings:            2
legacy duplicate conditional sites:         0
Git Bash syntax failures:                   0
protected production diff:                  0
report scenario rows:                     727
report exact ending:                      PASS
uncommitted production diff:                0
```

## Final decision

TASK-4.3 is accepted and completed.

TASK-4.4 may open. TASK-4.5 and later tasks remain locked.
