# TASK-3.4 Review

Implementation commit reviewed: `339ca0129da1af9a87cd5e3bbca7ffff17085352`

Production source review: **ACCEPTED**

Final status: **COMPLETED**

TASK-3.5 may open: **YES**

## Scope

The implementation commit contains exactly:

```text
M AppDataBackupManager.m
A docs/backup-restore-hardening/reports/TASK-3.4-REPORT.md
```

No other production file changed. The accepted TASK-3.1 workspace, TASK-3.2 bundle lock and TASK-3.3 artifact writer sources remain byte-identical.

## Accepted request/inclusion split

The manager now records two separate facts:

```objc
BOOL preferencesRequested =
    (options & PXBackupOptionIncludePreferences) != 0;

BOOL preferencesIncluded = (preferencesArtifactRecord != nil);
```

`preferencesRequested` controls the attempt and raw `options.includePreferences` telemetry. `preferencesIncluded` is true only after the TASK-3.3 writer returned a verified immutable Preferences record.

Independent source counts:

```text
preferencesRequested declarations: 1
preferencesIncluded declarations:  1
prefsIncluded tokens:               0
prefDestPath tokens:                0
```

## Exact relative-path authority

The exact relative locator is built once:

```objc
NSString *preferencesRelativePath =
    [NSString stringWithFormat:@"preferences/%@.plist", bundleID];
```

It is reused by the writer and by the excluded manifest-v3 locator. There is no final-path rescan and no synthetic artifact dictionary.

## Manifest-v3 compatibility

The Preferences section now uses:

```objc
@"preferences": @{
    @"included": @(preferencesIncluded),
    @"archive": preferencesIncluded
        ? preferencesArtifactRecord.relativePath
        : preferencesRelativePath
},
```

This satisfies the existing manifest-v3 requirement that `preferences.archive` remain nonempty even when excluded. The excluded locator creates no artifact authority because no verified declaration is emitted and the accepted Restore verifier/plan ignore it when `included` is false.

Static proof:

```text
preferences.included from verified result: 1
exact included/excluded archive ternary:   1
empty Preferences archive fallback:        0
Preferences record conditional insertion:  1
Preferences artifact path rescans:          0
```

## Included/excluded option reporting

Both private option-name helpers now accept the verified inclusion Boolean. `GlobalPreferences` is included only after verified output and excluded otherwise. App Groups and Keychain retain their prior option-based behavior and canonical ordering.

The nested options dictionary retains raw request telemetry:

```objc
@"includePreferences": @(preferencesRequested)
```

The helpers contain zero direct `PXBackupOptionIncludePreferences` checks.

## Production outcome matrix

```text
not requested:
  no writer attempt
  included false
  no warning

requested + source missing:
  exact existing missing-source warning
  included false

requested + copy/writer failure:
  no new warning
  included false
  Backup continues

requested + verified writer success:
  included true
  exact verified relative path
  one matching artifact declaration
```

Formal optional failure and zero-length policy remain deferred to TASK-3.5 as required.

## Non-regression

Independent gates confirmed:

```text
writer semantic sites:       8
writer factory calls:        1
writer validations:          3
lock factory calls:          1
lock validations:            4
workspace factory calls:     1
workspace validations:       3
legacy artifact helper tokens: 0
manifestVersion 3:           retained
final Backup publication:    0
warning append sequence diff: 0
Restore method body:         unchanged
backup discovery body:       unchanged
timestamp helper body:       unchanged
```

The report contains 126 explicit scenarios and ends with the required status lines.

`git show --check` and the cumulative baseline diff check both pass. `AppDataBackupManager.m` retains 17 pre-existing trailing-whitespace lines; `git diff --check` confirms TASK-3.4 added none. The report contains no trailing whitespace or NUL bytes.

## Build status

The report records a strict Objective-C frontend harness pass for the exact helper, Preferences production, verified-record insertion and manifest expressions. This Windows workspace has no Apple Clang/Theos linked artifact. Owner continuation is accepted as build-status confirmation, and no source evidence contradicts it.

## Verdict

TASK-3.4 is **ACCEPTED** and **COMPLETED**.

TASK-3.5 may define the formal required/optional, failure-disposition and zero-length policy. TASK-3.6 and all later publication tasks remain locked.
