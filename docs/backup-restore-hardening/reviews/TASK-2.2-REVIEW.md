# TASK-2.2 Review — Enforce Supported Manifest Versions

Implementation commit reviewed: `9727a0a1e14f4229ee46a74b5f5bf5fcf92bb951`

Production source review: **ACCEPTED**

Final status: **COMPLETED**

Build gate: **PASSED — accepted from project-owner continuation**

No GitHub Actions artifact or compiled package is stored in this workspace, so the coordinator independently reviewed source, commit scope and static gates.

## Scope

The implementation commit contains exactly:

```text
M AppDataBackupManager.m
A docs/backup-restore-hardening/reports/TASK-2.2-REPORT.md
```

Protected production files are unchanged, including:

```text
AppDataBackupManager.h
PXBackupManifestValidator.h
PXBackupManifestValidator.m
AppDataCleaner.h/.m
CommandRunner.h/.m
AppGroupContainerResolver.h/.m
Makefile
UI/controller files
Keychain helper and bridge files
```

## Accepted version policy

`PXBackupManifestVersionIsSupported` is file-local and implements the exact closed set:

```text
2
3
```

Accepted behavior:

```text
version 1   -> unsupported
version 2   -> supported
version 3   -> supported
version 4   -> unsupported
version 999 -> unsupported
```

No minimum, maximum, numeric range, newest-version fallback or warning-and-continue policy was introduced.

The current Backup writer remains version 3.

## Common manifest-read boundary

`readManifestAtBackupDirectory:error:` now performs the required order:

1. clears `*error` when provided;
2. reads `manifest.plist` once;
3. preserves manager read error code `200` for missing/unreadable/non-dictionary input;
4. invokes `PXBackupManifestValidator` exactly once;
5. propagates the validator error object without wrapping;
6. invokes the supported-version helper exactly once;
7. returns manager error code `201` for unsupported versions;
8. returns the original dictionary on success.

The unsupported-version error uses the generic description:

```text
Unsupported backup manifest version
```

It does not include the actual version, backup directory, bundle ID, path, UUID or manifest excerpt.

## Restore integration and ordering

`restoreBackupAtDirectory:bundleID:appName:completion:` now calls the public manifest-read method exactly once and contains no direct manifest plist load, validator call or version-helper call.

Manifest schema/version rejection occurs before:

```text
warnings allocation
debug path construction
debug writes and debug commands
CommandRunner acquisition for Restore
tar discovery
target-process termination
LaunchServices lookup
metadata target scan
manifest path/UUID fallback
artifact verification
archive extraction
any restore mutation
```

A manifest-read failure is dispatched to completion on the main queue once and returns immediately.

## TASK-2.3 and TASK-2.4 boundaries preserved

TASK-2.2 intentionally retains the existing bundle mismatch warning:

```text
Restore target bundle mismatch
```

It does not convert mismatch to failure. Exact requested-target identity remains TASK-2.3.

The following destination behavior remains present for TASK-2.4:

```text
LaunchServices target preference
metadata scan
manifest data.containerPath fallback
manifest data.uuid fallback
existing fallback warnings
```

Supported version is not treated as destination authorization.

## Independent static evidence

```text
git show --check --oneline 9727a0a: PASS
git diff e15f101..9727a0a --check: PASS
protected production diff: clean
validator import count: 1
version-helper definition count: 1
version-helper total references: 2 (definition + one call)
validator call count: 1
Restore readManifest call count: 1
Restore direct dictionaryWithContentsOfFile count: 0
Restore direct validator call count: 0
Restore direct version-helper call count: 0
unsupported manager code 201 count: 1
Backup writer manifestVersion @3 count: 1
bundle mismatch warning count: 1
manifest containerPath fallback warning count: 1
manifest UUID fallback warning count: 1
minimum/range-policy token count: 0
```

Whitespace and file-integrity gates:

```text
commit whitespace check: PASS
cumulative whitespace check: PASS
report trailing whitespace: 0
report NUL bytes: 0
```

## Non-blocking runtime note

Static review does not independently prove Foundation plist loading, exact `NSError` object identity as observed by every caller, main-queue callback timing or behavior on device. The owner continuation is treated as the build gate for this workflow.

## Final verdict

TASK-2.2 satisfies its source contract and is accepted.

TASK-2.3 may open. TASK-2.4 and later Phase 2 work remain locked.
