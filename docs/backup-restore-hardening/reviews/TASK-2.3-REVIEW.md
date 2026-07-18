# TASK-2.3 Review — Exact Restore Bundle Identity

Implementation commit reviewed: `1c5eda02e91c5705e7798ef2414475f3aebfcef2`

Production source review: **ACCEPTED**

Final status: **COMPLETED**

## Scope

The implementation commit contains exactly:

```text
M AppDataBackupManager.m
A docs/backup-restore-hardening/reports/TASK-2.3-REPORT.md
```

No protected production file changed.

## Accepted behavior

`restoreBackupAtDirectory:bundleID:appName:completion:` now performs exact requested-target identity enforcement immediately after the common manifest reader succeeds.

The accepted comparison is:

```objc
NSString *manifestBundleID = manifest[@"bundleID"];
if (![manifestBundleID isEqualToString:bundleID]) {
    ...
}
```

The comparison is:

- exact;
- case-sensitive;
- non-normalizing;
- non-trimming;
- not prefix, suffix or substring based;
- independent of app name, company name, profile ID, path and UUID.

The mismatch result is:

```text
domain: com.hydra.projectx.backup
code: 304
description: Backup manifest bundle identifier does not match restore target
```

The error does not contain either bundle identifier, the backup directory, a path, UUID, archive name or manifest excerpt.

## Ordering

Independent line-order review confirms:

```text
common manifest reader        1759
manifest bundle extraction    1769
exact bundle comparison       1770
warnings allocation           1778
CommandRunner acquisition     1780
debug write path              1788
tar discovery                 1808
process kill                  1837
LaunchServices target lookup  1860
```

A mismatched manifest therefore returns before:

- warnings/debug setup;
- filesystem diagnostics;
- tar discovery;
- process termination;
- target-container lookup;
- artifact verification;
- archive extraction;
- any Restore mutation.

## Removed warning-and-continue behavior

The previous warning string is absent:

```text
Restore target bundle mismatch: backup bundle %@, requested bundle %@
```

There is no second requested-target comparison later in Restore and no warning-and-continue branch.

## TASK-2.2 non-regression

The following remain unchanged:

- `readManifestAtBackupDirectory:error:` is the common read/schema/version boundary;
- Restore calls the common reader exactly once;
- Restore directly loads the manifest zero times;
- Restore directly invokes the schema validator zero times;
- exact supported versions remain `{2, 3}`;
- malformed manifest errors remain validator errors;
- unsupported versions remain manager code `201`;
- Backup writer remains manifest version `3`.

## TASK-2.4 boundary preserved

The implementation intentionally retains:

- LaunchServices target preference;
- metadata-scan fallback;
- manifest `data.containerPath` fallback;
- manifest `data.uuid` fallback;
- corresponding fallback warnings.

Those recorded-destination fallbacks remain unsafe and are assigned to TASK-2.4.

## Independent static evidence

```text
git show --check: PASS
baseline-to-commit diff --check: PASS
protected production diff: clean
Restore common-reader calls: 1
Restore direct manifest loads: 0
Restore direct validator calls: 0
bundle mismatch code 304: 1
generic mismatch description: 1
old mismatch warning: 0
exact requested-target comparison: 1
case-insensitive/normalizing/fuzzy target tokens: 0
manifest containerPath fallback warnings: 1
manifest UUID fallback warnings: 1
Backup writer manifestVersion @3: 1
```

`AppDataBackupManager.m` contains pre-existing trailing whitespace outside the TASK-2.3 additions. The implementation commit adds no trailing whitespace: both `git show --check` and the cumulative task diff check pass. The report contains no trailing whitespace or NUL bytes.

## Build gate

Build status is accepted from project-owner continuation to the next task. The workspace does not contain a GitHub Actions artifact or target-device runtime log for independent compilation/runtime verification.

## Remaining risk

Static review cannot prove target-device callback timing or every Foundation Unicode fixture. The exact `NSString` comparison and early return are source-verifiable and satisfy the task contract.

TASK-2.3 is accepted and TASK-2.4 may open.
