# TASK-1.4 — Remove Writes to Application Bundle Containers

## Metadata

- Phase: Phase 1 — Clear Data Safety Boundary
- Status: READY
- Dependency: TASK-1.3 accepted and project-owner build gate completed
- Required report: `docs/backup-restore-hardening/reports/TASK-1.4-REPORT.md`
- Allowed production file: `AppDataCleaner.m`
- Suggested commit: `phase1(task-1.4): remove application bundle writes`

## Goal

Application bundle containers contain installed application code and resources. Clear Data must not delete, recreate, chmod, chflags, wipe or otherwise mutate anything under an application bundle container.

TASK-1.4 removes every active application-bundle write path currently owned by `AppDataCleaner.m` while preserving read-only bundle discovery and public selector compatibility.

This task is behavior removal only. It must not:

- migrate application-data clearing to `PXDataContainerResolver`;
- import or invoke `PXDestructivePathValidator`;
- change data-container, App Group or PluginKit destructive behavior;
- introduce typed Clear requests or results;
- change UI/completion semantics;
- rewrite legacy bundle discovery;
- begin TASK-1.5 or later work.

## Required reading

Before editing, read:

1. `docs/backup-restore-hardening/README.md`
2. `docs/backup-restore-hardening/STATUS.md`
3. `docs/backup-restore-hardening/DECISIONS.md`
4. `docs/backup-restore-hardening/reviews/TASK-1.3-REVIEW.md`
5. `docs/backup-restore-hardening/reports/TASK-1.3-REPORT.md`
6. `docs/backup-restore-hardening/templates/AGENT_REPORT_TEMPLATE.md`
7. `PXResolvedContainer.h`
8. `PXResolvedContainer.m`
9. `PXDataContainerResolver.h`
10. `PXDataContainerResolver.m`
11. `PXDestructivePathValidator.h`
12. `PXDestructivePathValidator.m`
13. `AppDataCleaner.h`
14. the complete `AppDataCleaner.m`
15. `Makefile`

The full-file review is mandatory because generic destructive helpers such as `fixPermissionsAndRemovePath:` and `wipeDirectoryContents:` are shared by bundle and non-bundle paths.

## Allowed changes

Only modify:

```text
AppDataCleaner.m
```

Create exactly one report:

```text
docs/backup-restore-hardening/reports/TASK-1.4-REPORT.md
```

## Protected files

Do not modify:

```text
AppDataCleaner.h
PXResolvedContainer.h
PXResolvedContainer.m
PXDataContainerResolver.h
PXDataContainerResolver.m
PXDestructivePathValidator.h
PXDestructivePathValidator.m
Makefile
CommandRunner.h
CommandRunner.m
AppGroupContainerResolver.h
AppGroupContainerResolver.m
AppDataBackupManager.h
AppDataBackupManager.m
```

Do not modify Clear UI, Backup, Restore, Keychain or unrelated source.

## Application bundle roots

For this task, application bundle containers include all of these roots:

```text
/var/containers/Bundle/Application
/var/mobile/Containers/Bundle/Application
/containers/Bundle/Application
```

Any descendant of one of these roots is application bundle content.

Examples include:

- `.app` directories;
- `.appex` directories;
- `Info.plist`;
- `_MASReceipt` and `._MASReceipt`;
- `PlugIns` and `Plugins`;
- the rootless bundle container itself.

TASK-1.4 must leave these locations read-only from `AppDataCleaner`.

## Existing write inventory

The baseline contains four write families that must be removed.

### 1. Rootless application-bundle full wipe

`completeAppDataWipe:` currently constructs:

```objc
NSString *rootlessBundlePath =
    [NSString stringWithFormat:@"/containers/Bundle/Application/%@", bundleUUID];
```

and executes an `rm -rf <bundle>/*` shell command.

Remove this entire mutation block.

Do not replace it with a different deletion method, validator call, Foundation removal, rename, truncate, permission change or marker file.

### 2. Main application receipt mutation

The public selector:

```objc
- (void)clearAppReceiptData:(NSString *)bundleID
             withBundleUUID:(NSString *)bundleUUID;
```

currently:

- scans rootful and rootless bundle directories;
- locates an app bundle;
- chmods/chflags and removes `_MASReceipt`;
- recreates an empty receipt directory.

This selector must remain implemented for ABI/source compatibility, but its implementation must become a non-mutating compatibility no-op.

### 3. Extension bundle receipt mutation

`clearExtensionContainers:forApp:` currently uses each extension bundle UUID to locate `.appex` code and remove its `_MASReceipt` directory.

Remove the entire extension-bundle receipt write section.

Preserve extension data-container cleaning, keychain handling, preference cleanup and all later non-bundle steps.

### 4. Dormant single-argument receipt implementation

The private implementation:

```objc
- (void)clearAppReceiptData:(NSString *)bundleID;
```

has no current caller but still contains active application-bundle wipe logic.

Remove this entire method implementation so the dormant write path cannot later be called accidentally.

Do not add it to the public header and do not replace it with another selector.

## Required public compatibility behavior

Keep the public header unchanged.

The public two-argument selector must remain present exactly once in `AppDataCleaner.m`:

```objc
- (void)clearAppReceiptData:(NSString *)bundleID
             withBundleUUID:(NSString *)bundleUUID;
```

Its body must:

1. perform no filesystem read or write;
2. launch no command;
3. not construct an application bundle path;
4. not inspect `bundleUUID` to select a target;
5. not touch `_MASReceipt`;
6. log one concise message explaining that application bundle receipt mutation is intentionally skipped;
7. return normally.

Recommended implementation shape:

```objc
- (void)clearAppReceiptData:(NSString *)bundleID
             withBundleUUID:(NSString *)bundleUUID {
    (void)bundleUUID;
    [self logMessage:@"[AppDataCleaner] Skipping App Store receipt removal for %@; application bundle containers are read-only",
                     bundleID ?: @"<unknown>"];
}
```

Equivalent wording is allowed, but it must not claim that receipt data was cleared.

Do not change the return type or selector.

## Required changes in `completeAppDataWipe:`

Keep the existing call:

```objc
[self clearAppReceiptData:bundleID withBundleUUID:bundleUUID];
```

It now reaches the compatibility no-op and preserves caller ordering/log flow.

Remove only the block that:

- creates `rootlessBundlePath`;
- checks it with `fileExistsAtPath:`;
- executes `rm -rf` on its contents.

Do not remove or rewrite:

- cached bundle directory enumeration;
- `bundleUUID` discovery;
- extension discovery inputs;
- bundle UUID logging;
- data-container wiping;
- group wiping;
- extension data clearing;
- other non-bundle operations.

`bundleUUID` may remain because it is used by the public compatibility call and diagnostic logging.

## Required changes in `clearExtensionContainers:forApp:`

Remove the complete section beginning with the extension bundle receipt comment and ending before extension keychain handling.

This includes:

- reading `extension[@"bundleUUID"]` into a local variable when that value is used only for receipt mutation;
- selecting bundle rootful/rootless bases;
- enumerating `.appex` and `PlugIns`/`Plugins` for receipt mutation;
- reading Info.plist for the purpose of selecting a receipt deletion target;
- creating receipt paths;
- invoking `fixPermissionsAndRemovePath:` for receipt paths.

After the change, the method must still perform:

1. extension or PluginKit data-container cleanup;
2. extension keychain cleanup;
3. extension preferences cleanup;
4. remaining existing non-bundle cleanup in the same order.

Do not change the shape of `extensionInfo` dictionaries in this task. Existing discovery may continue to include a `bundleUUID` key for compatibility even though this method no longer consumes it.

## Read-only bundle behavior that must remain

TASK-1.4 must not remove application bundle reads needed by existing non-mutating behavior.

Preserve:

- `PXKillAppProcessBestEffort` fallback reading bundle Info.plist/`CFBundleExecutable`;
- cached rootful/rootless bundle directory listings used for discovery;
- `findBundleUUID:`;
- `findBundleContainerUUID:`;
- `optimized_findBundleContainerUUID:inDirectories:rootlessDirs:`;
- `findBundleUUIDForExtension:`;
- `findRootlessBundleUUIDForExtension:`;
- `findBundleContainerUUIDForBundleID:`;
- extension discovery that reads bundle Info.plist;
- `getDataUsage:` bundle size calculation;
- `AppEntitlementsReader` and keychain backup read-only bundle scans.

Do not attempt to harden or replace these read-only resolvers in TASK-1.4.

## Generic destructive helpers

Do not modify these generic helpers in TASK-1.4:

```objc
- (void)fixPermissionsAndRemovePath:(NSString *)path;
- (void)fixPermissionsForPath:(NSString *)path;
- (void)wipeDirectoryContents:(NSString *)path
       keepDirectoryStructure:(BOOL)keepDirectoryStructure;
- (void)completelyWipeContainer:(NSString *)containerPath;
- (BOOL)securelyWipeFile:(NSString *)path;
```

They are used by non-bundle cleanup paths and are scheduled for later safety/migration tasks.

Instead, remove every in-file call path that supplies an application-bundle descendant to those helpers.

The report must acknowledge that public generic helpers can still be misused by an external caller. Quarantining broad public APIs belongs to TASK-1.12, not TASK-1.4.

## No validator integration

Do not import or instantiate:

```text
PXResolvedContainer
PXDataContainerResolver
PXDestructivePathValidator
```

in `AppDataCleaner.m` during this task.

Application bundles are intentionally not representable as `PXResolvedContainerKind`; therefore TASK-1.4 removes writes rather than trying to validate or authorize them.

## No replacement mutation

Removed bundle writes must not be replaced by any of the following:

- `removeItemAtPath:`;
- `trashItemAtURL:`;
- `moveItemAtPath:` or rename/quarantine;
- `createDirectoryAtPath:`;
- `createFileAtPath:`;
- `writeToFile:`;
- `setAttributes:`;
- `chmod`, `fchmod`, `chown`, `fchown`;
- `chflags`;
- `unlink`, `rmdir`, `remove`;
- `truncate` or `ftruncate`;
- shell `rm`, `find -delete`, `mv`, `cp`, `touch`, `mkdir`, redirection or overwrite;
- CommandRunner direct execution;
- a helper/daemon request;
- marker-file creation;
- receipt directory recreation.

The desired behavior is omission of application-bundle mutation.

## Caller and result compatibility

Do not change:

- `clearDataForBundleID:completion:` completion behavior;
- success/failure mapping;
- keychain result propagation;
- task ordering except removal of bundle writes;
- public method declarations;
- UI messages or controller behavior;
- data/container discovery return shapes;
- `extensionInfo` dictionary schema;
- Backup/Restore behavior.

Receipt skipping is not a Clear failure in TASK-1.4. Structured component results do not exist yet and belong to TASK-1.6.

## Required source gates

After TASK-1.4, verify `AppDataCleaner.m` has:

```text
single-argument clearAppReceiptData implementation: 0
two-argument clearAppReceiptData implementation: 1
_MASReceipt tokens: 0
._MASReceipt tokens: 0
rootlessBundlePath tokens: 0
application-bundle receipt deletion logs: 0
application-bundle receipt recreation: 0
extension receipt deletion section: 0
```

The two-argument compatibility method body must contain zero occurrences of:

```text
Bundle/Application
_MASReceipt
listDirectoriesInPath
fileExistsAtPath
fixPermissionsAndRemovePath
wipeDirectoryContents
createDirectoryAtPath
removeItemAtPath
runCommandWithPrivileges
CommandRunner
```

The `clearExtensionContainers:forApp:` body must contain zero occurrences of:

```text
_MASReceipt
Clearing extension receipt
fixPermissionsAndRemovePath:receiptPath
/var/containers/Bundle/Application/
/containers/Bundle/Application/
```

The `completeAppDataWipe:` body must contain zero occurrences of:

```text
rootlessBundlePath
rm -rf %@/*
```

when associated with an application bundle path.

Read-only bundle-root literals may remain elsewhere and must be audited in the report.

## Application-bundle occurrence audit

The report must list every remaining active occurrence of:

```text
Bundle/Application
```

in all production source files.

For each occurrence, record:

- file and method/function;
- root path;
- purpose;
- APIs used;
- whether it reads, writes or launches a command;
- why it is read-only;
- whether it remains required.

Every remaining occurrence in `AppDataCleaner.m` must be classified read-only.

Any remaining write or command target under an application bundle root is a task failure.

## Required call-site audit

Report all callers of:

```objc
clearAppReceiptData:withBundleUUID:
```

Expected baseline callers include:

- `completeAppDataWipe:`;
- `performFullCleanup:`.

For each caller, confirm:

- caller remains present;
- call ordering is unchanged;
- call now reaches a non-mutating compatibility method;
- no replacement bundle mutation was added nearby.

Also prove that the removed single-argument selector has zero callers and zero implementation after the task.

## Baseline and protected checksums

Before editing, record:

```text
git status --short
git rev-parse HEAD
```

Record initial and final SHA-256 for:

```text
AppDataCleaner.h
PXResolvedContainer.h
PXResolvedContainer.m
PXDataContainerResolver.h
PXDataContainerResolver.m
PXDestructivePathValidator.h
PXDestructivePathValidator.m
Makefile
CommandRunner.h
CommandRunner.m
AppGroupContainerResolver.h
AppGroupContainerResolver.m
AppDataBackupManager.h
AppDataBackupManager.m
```

All must remain byte-for-byte unchanged.

If TASK-1.3 files are still untracked at baseline:

- record that state explicitly;
- do not edit, stage, revert or format them;
- prove their initial/final checksums are equal;
- use file-specific diffs so TASK-1.4 changes remain reviewable.

## Required scenario matrix

The report must cover at least:

| # | Scenario | Required outcome |
|---:|---|---|
| 1 | normal rootful app Clear | no application-bundle write; other existing cleanup continues |
| 2 | normal rootless app Clear | rootless application bundle remains untouched |
| 3 | public receipt selector called directly | one skip log; no filesystem or command operation |
| 4 | public receipt selector receives nil bundle UUID | skip log; no mutation and no exception |
| 5 | public receipt selector receives nil bundle ID dynamically | safe skip log using fallback text; no mutation |
| 6 | `completeAppDataWipe:` resolves bundle UUID | UUID may be logged/read, but bundle is not changed |
| 7 | `performFullCleanup:` calls receipt selector | compatibility no-op; remaining flow continues |
| 8 | extension with rootful bundle UUID | extension data may be cleaned; extension code/receipt untouched |
| 9 | extension with rootless bundle UUID | extension data may be cleaned; rootless extension code/receipt untouched |
| 10 | extension dictionary still contains bundleUUID | schema preserved; value ignored for mutation |
| 11 | dormant single-argument selector invoked through source search | impossible; implementation and callers are absent |
| 12 | bundle Info.plist process-name lookup | read-only behavior remains |
| 13 | bundle UUID discovery | read-only behavior remains |
| 14 | bundle size calculation | read-only behavior remains |
| 15 | app receipt directory already absent | no recreation occurs |
| 16 | app receipt directory exists and is immutable | no chmod/chflags/removal attempted |
| 17 | external caller passes bundle path to generic public removal helper | still possible legacy risk; outside TASK-1.4 and reported |
| 18 | successful Clear completion | unchanged except bundle-write omission |

Runtime rows not executed must be labeled `STATIC REVIEW`, not `PASS`.

## Report requirements

Create:

```text
docs/backup-restore-hardening/reports/TASK-1.4-REPORT.md
```

The report must include:

1. task metadata;
2. initial working-tree state;
3. allowed/protected file verification;
4. baseline write inventory;
5. exact code removed;
6. public compatibility selector implementation;
7. `completeAppDataWipe:` audit;
8. `clearExtensionContainers:forApp:` audit;
9. removed dormant selector proof;
10. caller audit;
11. remaining application-bundle occurrence audit;
12. proof all remaining bundle uses are read-only;
13. proof no replacement mutation exists;
14. protected-file checksum table;
15. source-token gate results;
16. full scenario matrix;
17. full diff and diff-stat review;
18. whitespace checks;
19. generated/binary/NUL-byte audit;
20. remaining risks;
21. GitHub Actions handoff.

End with:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

## Verification commands

At minimum run and record:

```text
git status --short
git rev-parse HEAD
git diff --check
git diff --stat -- AppDataCleaner.m
git diff -- AppDataCleaner.m
git diff --exit-code -- <protected files>
```

Also perform:

- exact selector declaration/implementation counts;
- `_MASReceipt` and `._MASReceipt` count;
- `rootlessBundlePath` count;
- all `Bundle/Application` occurrence review;
- all caller search;
- no new production-file references to resolver/validator classes;
- no generated or binary file audit;
- trailing-whitespace and NUL-byte checks.

## Acceptance checklist

- [ ] Only `AppDataCleaner.m` changes as production code.
- [ ] Required report exists.
- [ ] Rootless bundle full-wipe block is gone.
- [ ] Public receipt selector remains and is a pure compatibility no-op.
- [ ] Public header is unchanged.
- [ ] Main app receipt mutation is gone.
- [ ] Extension receipt mutation is gone.
- [ ] Dormant single-argument receipt implementation is gone.
- [ ] `_MASReceipt` and `._MASReceipt` tokens are absent from `AppDataCleaner.m`.
- [ ] No application-bundle receipt directory is recreated.
- [ ] No replacement application-bundle write is introduced.
- [ ] Generic helpers remain unchanged.
- [ ] Read-only bundle discovery and inspection remain unchanged.
- [ ] Extension data-container cleaning remains unchanged.
- [ ] Completion and result semantics remain unchanged.
- [ ] No resolver/validator integration is introduced.
- [ ] Protected files remain unchanged.
- [ ] Remaining bundle references are fully audited and read-only.
- [ ] `git diff --check` passes.
- [ ] GitHub Actions succeeds.
- [ ] Coordinator review accepts the task.
- [ ] Agent stops after TASK-1.4.

## Stop condition

After completing TASK-1.4:

- do not implement TASK-1.5;
- do not create `PXClearRequest`;
- do not create `PXClearResult`;
- do not migrate main data-container clearing;
- do not import the resolver or validator into `AppDataCleaner`;
- do not modify application bundle contents through another path;
- stop and wait for coordinator review.

## Gate after TASK-1.4

TASK-1.5 may be specified only after:

1. the TASK-1.4 report is complete;
2. source review confirms all application-bundle writes are removed;
3. read-only bundle behavior remains intact;
4. GitHub Actions succeeds;
5. coordinator creates an accepted TASK-1.4 review.
