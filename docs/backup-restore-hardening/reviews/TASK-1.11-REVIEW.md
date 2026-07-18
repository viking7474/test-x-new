# TASK-1.11 Review

## Verdict

```text
Task: TASK-1.11
Baseline: 7b277bfd2579e53f0015b89ef36b43440688590b
Implementation commit reviewed: 17d76c02e049b40bf84a161d76e90ec02b9485bf
Build gate: PASSED — accepted from project-owner continuation; no CI artifact is stored in this workspace
Production source review: ACCEPTED
Final status: COMPLETED
Next gate: TASK-1.12
```

TASK-1.11 is accepted. `AppDataCleaner.m` no longer performs general recursive permission or ownership rewriting, creates the legacy Clear markers, or copies a database timestamp onto a system framework executable. The accepted typed Clear and Keychain paths remain unchanged.

## Scope reviewed

The implementation commit contains exactly:

```text
M AppDataCleaner.m
A docs/backup-restore-hardening/reports/TASK-1.11-REPORT.md
```

No protected production file changed. In particular, the task did not modify:

- `AppDataCleaner.h`;
- the exact container models, resolvers or validator;
- `PXClearRequest` or `PXClearResult`;
- `CommandRunner`;
- App Group resolution;
- Backup or Restore;
- Keychain helper/bridge files;
- UI files;
- `Makefile`.

## Accepted implementation

### Recursive permission and ownership removal

The final `AppDataCleaner.m` contains:

```text
chmod -R: 0
find ... -exec chmod: 0
chown -R: 0
```

The two fixed recreated-directory ownership operations for MobileMail and MobileSafari WebKit are now non-recursive `chown mobile:mobile` operations. No descendant ownership traversal remains in Clear.

### Flag mutation boundary

The file contains exactly one `chflags -R` occurrence. It remains inside the unchanged `PXShellValidatedApplicationDataWipe` script and is limited to immediate non-metadata children of a canonical validator-authorized container.

Generic/raw-path flag preparation was removed from:

- `PXShellFinalSweep`;
- `fixPermissionsAndRemovePath:`;
- `fastWipeDirectoryContents:keepDirectoryStructure:timeoutSec:`;
- `fixPermissionsForPath:`.

### Marker and timestamp removal

The following final counts are zero:

```text
active shell touch
.nomedia
.initialized
AssistantServices.framework/AssistantServices
```

`completelyWipeContainer:` still preserves the two MCM metadata filename patterns and recreates its compatibility directory structure, but it no longer creates marker files or rewrites modes.

`cleanSiriAnalyticsDatabase:` retains its SQLite operations and `VACUUM`, but no longer writes a SiriAnalytics timestamp onto a system framework binary.

### Compatibility helpers

`fixPermissionsAndRemovePath:` now:

1. validates the input shape;
2. returns when the path is absent;
3. attempts Foundation removal;
4. uses one quoted bounded `rm -rf` fallback only after Foundation failure.

It contains no chmod, chown or chflags preparation.

`fixPermissionsForPath:` is a read/log-only compatibility no-op and performs no command or filesystem mutation.

### Legacy wipe helpers

The task removed permission preparation without broad redesign:

- `PXShellFinalSweep` is deletion-only;
- fast wipe executes only its existing quoted deletion fragment;
- WebKit wipe no longer recursively chmods its input;
- aggressive cleanup no longer recursively chmods `Library`;
- complete-container compatibility wipe no longer changes permissions or creates markers.

These selectors remain ambiguous raw-path or heuristic APIs. Their deletion behavior is intentionally left for TASK-1.12 quarantine.

### Narrow task-owned modes preserved

The task correctly retained:

```text
NSFilePosixPermissions @0700 for the unique Keychain temporary directory
chmod(..., 0755) for the request-local copied Keychain helper
three non-recursive chmod 0644 operations on task-owned /var/tmp plist files
```

These operations are narrow and do not rewrite an arbitrary directory tree.

## Typed Clear non-regression

The report recorded identical before/after body hashes for the accepted typed path, including:

- `PXShellValidatedApplicationDataWipe`;
- `PXApplicationDataCommandResultSucceeded`;
- `PXApplicationDataPostconditionIsValid`;
- `_completeDataWipeForMigratedRequest:`;
- exact ExtensionData/PluginKitData execution;
- exact AppGroups execution;
- Keychain plan, execution and component construction;
- `clearDataForBundleID:completion:`;
- `completeAppDataWipe:`.

Independent diff review found no changed hunk inside those protected bodies.

The final contracts remain:

```text
Data aggregate: ApplicationData, ExtensionData, AppGroups, PluginKitData
Full aggregate: ApplicationData, ExtensionData, AppGroups, PluginKitData, Keychain
completeAppDataWipe: data-only
callback precedence: ApplicationData -> ExtensionData -> AppGroups -> PluginKitData -> Keychain
```

No receipt mutation returned, and `PXClearScopeDefaultMask` remains absent from the migrated orchestration.

## Independent verification

The coordinator reran:

```text
git show --check --oneline 17d76c0
git diff 7b277bfd2579e53f0015b89ef36b43440688590b..17d76c02e049b40bf84a161d76e90ec02b9485bf --check
git diff --exit-code <baseline>..<implementation> -- <protected files>
```

Results:

```text
git show --check: PASS
cumulative diff --check: PASS
protected-file diff: PASS
exact implementation file scope: PASS
```

Independent final token counts:

```text
chmod -R = 0
find -exec chmod = 0
chown -R = 0
chflags -R = 1
shell touch = 0
.nomedia = 0
.initialized = 0
AssistantServices target = 0
Keychain temporary 0700 = 1
Keychain helper 0755 = 1
narrow chmod 0644 = 3
receipt tokens = 0
PXClearScopeDefaultMask = 0
```

The report file and implementation commit pass whitespace checks and contain no NUL bytes.

## Evidence note

The report describes the post-commit commands as reserved for execution rather than pasting their final output and does not record the resulting implementation SHA in its final section. The coordinator independently executed those commands against commit `17d76c02e049b40bf84a161d76e90ec02b9485bf`, so this documentation gap does not block source acceptance.

## Remaining risks handed to TASK-1.12

The following compatibility paths remain callable and may still select targets from arbitrary paths, raw UUID state, prefix/substring matching or filesystem structure:

- raw-path wipe helpers;
- broad full/aggressive cleanup aliases;
- fuzzy related-container and system-group scans;
- structure-based shared-container scrubs;
- the generic `securelyWipeFile:` selector.

TASK-1.12 must quarantine those paths without changing the accepted typed five-scope result, resolver/validator contracts, Keychain accounting, public selector ABI, Backup or Restore.
