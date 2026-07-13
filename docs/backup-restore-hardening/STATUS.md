# Implementation Status

## Current Gate

```text
Program: Backup / Restore Hardening
Current phase: Phase 1 — Clear Data Safety Boundary
Current task: TASK-1.8 — Migrate ExtensionData and PluginKitData Clear
Task file: docs/backup-restore-hardening/tasks/TASK-1.8-migrate-extension-and-pluginkit-data-clear.md
Expected report: docs/backup-restore-hardening/reports/TASK-1.8-REPORT.md
Status: READY
Build owner: Project owner via GitHub Actions
Next task: TASK-1.9 remains LOCKED
```

## Accepted foundation

### Phase 0 — Reliable Command Execution

Completed outcomes:

- structured `CommandResult`;
- bounded stdout/stderr capture;
- monotonic deadlines;
- spawn-time process groups;
- bounded process-group termination and reap;
- direct executable/argv support;
- bounded `AppDataCleaner` command wrappers;
- bounded direct `find` helpers.

### TASK-1.1 — Immutable resolved identity

`PXResolvedContainer` provides exact immutable identity, kind/root, UUID/path consistency and value semantics. It is not deletion authorization.

### TASK-1.2 — Exact application-data resolver

`PXDataContainerResolver` resolves one application-data root at a time using exact `MCMMetadataIdentifier` equality and fails closed on ambiguity.

### TASK-1.3 — Canonical destructive path validator

`PXDestructivePathValidator` enforces fixed bases, exact raw path equality, symlink rejection, canonical immediate-child containment, mount/device checks, ownership/mode checks, live metadata identity and final filesystem identity rechecks.

### TASK-1.4 — Application bundles read-only

Main Clear no longer writes application bundles or receipts. Remaining bundle discovery is read-only.

### TASK-1.5 — Typed immutable request

`PXClearRequest` provides a strict bundle identifier, closed scope mask and explicit deep-clean intent.

### TASK-1.6 — Structured immutable result

`PXClearFailure`, `PXClearComponentResult` and `PXClearResult` provide immutable final outcomes, exact unit partitions, canonical aggregate coverage and explicit success/skip/failure semantics.

### TASK-1.7 — Main ApplicationData migrated

The primary application-data component now uses:

```text
exact root-specific resolver
  -> canonical validator
  -> canonical-path-only bounded command
  -> post-command validator
  -> strict postcondition
  -> PXClearComponentResult
```

Accepted commit:

```text
f98a0f6d9f52cb08f151c29520af6fb6e255616b — task 1.7
```

Accepted review:

```text
docs/backup-restore-hardening/reviews/TASK-1.7-REVIEW.md
```

Build:

```text
PASSED — reported by project owner
```

## TASK-1.8 purpose

The main flow still discovers extension containers by scanning mutable data-container metadata and accepting identifiers with the application bundle identifier as a prefix.

That behavior is unsafe because:

- prefix ownership is not exact identity;
- an unrelated identifier can share the prefix;
- extension identifiers do not have to follow a parent-prefix naming convention;
- raw UUID dictionaries are later converted into destructive paths;
- ExtensionData and PluginKitData are batched into void shell commands;
- command and postcondition failures are not represented structurally.

TASK-1.8 replaces this with:

1. exact read-only discovery of installed `.appex` identifiers inside the exact main `.app` bundle;
2. a generic exact data-container resolver for ApplicationData, ExtensionData and PluginKitData;
3. canonical validator output as the only mutable target path;
4. one bounded strict command per resolved container;
5. post-command revalidation and strict postcondition;
6. separate ExtensionData and PluginKitData component results;
7. a three-component migrated aggregate with ApplicationData;
8. legacy callback failure propagation.

## Exact extension identity source

The migrated flow must not infer extension ownership from:

```text
metadataIdentifier hasPrefix applicationBundleIdentifier
metadataIdentifier contains applicationBundleIdentifier
company or short-name matching
container contents
first match
```

The exact identifier set comes only from real, non-symlink `.appex` bundles physically contained in the exact main application bundle.

Allowed locations:

```text
<App>.app/<Extension>.appex
<App>.app/PlugIns/<Extension>.appex
<App>.app/Plugins/<Extension>.appex
```

Each extension identifier comes from exact `CFBundleIdentifier` in a regular non-symlink `Info.plist`.

## Resolver expansion

TASK-1.8 adds a generic method to `PXDataContainerResolver` while retaining the existing application-data method.

Allowed kinds:

```text
ApplicationData
ExtensionData
PluginKitData
```

AppGroup remains invalid for this resolver.

Fixed bases:

| Kind | Rootful | Rootless |
|---|---|---|
| ApplicationData | `/private/var/mobile/Containers/Data/Application` | `/containers/Data/Application` |
| ExtensionData | `/private/var/mobile/Containers/Data/Application` | `/containers/Data/Application` |
| PluginKitData | `/private/var/mobile/Containers/Data/PluginKitPlugin` | `/containers/Data/PluginKitPlugin` |

All matching remains exact, root-specific and ambiguity-failing.

## Unit policy

Deterministic order:

```text
ExtensionData
  extension identifiers ascending
    rootful
    rootless

PluginKitData
  extension identifiers ascending
    rootful
    rootless
```

For each `(scope, identifier, root)` tuple:

- absent container with no resolver error: not attempted;
- resolver/validation/execution/revalidation/postcondition error: one failed attempted unit;
- complete success: one succeeded unit;
- later unit failures do not stop remaining units.

## Result policy

### Extension discovery failure

If the exact main app bundle or exact `.appex` identity set cannot be established, both ExtensionData and PluginKitData fail with one synthetic discovery unit each.

No metadata-prefix fallback is allowed.

### No installed extensions

Both components are Skipped with:

```text
No installed application extensions were discovered
```

### No exact containers for one scope

ExtensionData:

```text
No exact extension-data containers were found
```

PluginKitData:

```text
No exact PluginKit data containers were found
```

### Partial outcome

Any failed unit makes the component `Failed`; mixed counts represent partial success.

## Migrated aggregate

The internal migrated request and aggregate contain exactly:

```text
ApplicationData
ExtensionData
PluginKitData
```

App Group and Keychain remain legacy side effects and are not included until TASK-1.9 and TASK-1.10.

Legacy callback failure precedence becomes:

```text
1. ApplicationData
2. ExtensionData
3. PluginKitData
4. Keychain
```

Skipped components are not callback failures.

## Canonical cache migration

The raw extension dictionary cache must be removed:

```text
_wipeCacheExtensionContainers
```

It is replaced by separate canonical path arrays for:

```text
ExtensionData
PluginKitData
```

Verification consumes those paths directly and never reconstructs them from UUIDs.

## TASK-1.8 gate rules

TASK-1.8 may move to `COMPLETED` only when all conditions are met:

- [ ] Agent creates `reports/TASK-1.8-REPORT.md`.
- [ ] Only `PXDataContainerResolver.h/.m` and `AppDataCleaner.m` change as production source.
- [ ] Generic resolver API is added exactly once.
- [ ] Existing application-data resolver remains and delegates to generic resolution.
- [ ] Generic resolver accepts exactly ApplicationData, ExtensionData and PluginKitData.
- [ ] Generic resolver rejects AppGroup and invalid kinds.
- [ ] Generic resolver keeps exact metadata identity and ambiguity failure.
- [ ] Installed extension identifiers come only from exact read-only `.appex` inspection.
- [ ] Migrated discovery contains no parent-prefix ownership test.
- [ ] Duplicate extension identifier at different paths fails closed.
- [ ] ExtensionData and PluginKitData use exact resolver + validator.
- [ ] Mutation uses canonical validator output only.
- [ ] One bounded result command runs per resolved container.
- [ ] Post-command validation and strict postcondition are required.
- [ ] Separate component results have exact unit accounting.
- [ ] Internal aggregate contains exactly three migrated components.
- [ ] Failure precedence is ApplicationData, ExtensionData, PluginKitData, Keychain.
- [ ] Raw extension dictionary cache is removed.
- [ ] Canonical ExtensionData and PluginKitData caches are used directly.
- [ ] Legacy extension discovery/mutation is unreachable from migrated main flow.
- [ ] ApplicationData TASK-1.7 behavior does not regress.
- [ ] App Group and Keychain are not migrated.
- [ ] Application bundles remain read-only.
- [ ] Protected files remain unchanged.
- [ ] `git diff --check`, whitespace and NUL gates pass.
- [ ] GitHub Actions succeeds or owner confirms build.
- [ ] Coordinator review accepts the task.

## Task history

| Task | Status | Report | Build | Review |
|---|---|---|---|---|
| TASK-0.1 | COMPLETED | `reports/TASK-0.1-REPORT.md` | PASSED | ACCEPTED |
| TASK-0.2 | COMPLETED | `reports/TASK-0.2-REPORT.md` | PASSED | ACCEPTED |
| TASK-0.3 | COMPLETED | `reports/TASK-0.3-REPORT.md` | PASSED reported by owner | ACCEPTED |
| TASK-0.4 | COMPLETED | `reports/TASK-0.4-REPORT.md` | PASSED reported by owner | ACCEPTED |
| TASK-0.5 | COMPLETED | `reports/TASK-0.5-REPORT.md` | PASSED reported by owner | ACCEPTED |
| TASK-0.6 | COMPLETED | `reports/TASK-0.6-REPORT.md` | PASSED reported by owner | ACCEPTED |
| TASK-0.7 | COMPLETED | `reports/TASK-0.7-REPORT.md` | PASSED reported by owner | ACCEPTED |
| TASK-1.1 | COMPLETED | `reports/TASK-1.1-REPORT.md` | PASSED reported by owner | ACCEPTED |
| TASK-1.2 | COMPLETED | `reports/TASK-1.2-REPORT.md` | PASSED reported by owner | ACCEPTED |
| TASK-1.3 | COMPLETED | `reports/TASK-1.3-REPORT.md` | PASSED reported by owner | ACCEPTED |
| TASK-1.4 | COMPLETED | `reports/TASK-1.4-REPORT.md` | PASSED reported by owner | ACCEPTED |
| TASK-1.5 | COMPLETED | `reports/TASK-1.5-REPORT.md` | PASSED reported by owner | ACCEPTED |
| TASK-1.6 | COMPLETED | `reports/TASK-1.6-REPORT.md` | PASSED reported by owner | ACCEPTED |
| TASK-1.7 | COMPLETED | `reports/TASK-1.7-REPORT.md` | PASSED reported by owner | `reviews/TASK-1.7-REVIEW.md` |
| TASK-1.8 | READY | Not created | Not run | Not reviewed |
| TASK-1.9 | LOCKED | Not created | Not run | Not reviewed |

## Working-tree baseline

At TASK-1.8 opening:

```text
HEAD: f98a0f6d9f52cb08f151c29520af6fb6e255616b
Working tree: clean before coordinator documentation updates
```

Coordinator-owned uncommitted files after opening TASK-1.8 may include:

```text
docs/backup-restore-hardening/DECISIONS.md
docs/backup-restore-hardening/README.md
docs/backup-restore-hardening/ROADMAP.md
docs/backup-restore-hardening/STATUS.md
docs/backup-restore-hardening/reviews/TASK-1.7-REVIEW.md
docs/backup-restore-hardening/tasks/TASK-1.8-migrate-extension-and-pluginkit-data-clear.md
```

The agent must treat those as protected coordinator baseline and must not rewrite the task specification.

## Blocked work

TASK-1.8 does not authorize:

- App Group migration;
- Keychain component result integration;
- extension Keychain migration;
- extension preference migration;
- global PlugInKit database/file cleanup as PluginKitData;
- legacy public helper quarantine;
- generic destructive helper redesign;
- Backup, Restore or UI changes;
- application-bundle writes;
- TASK-1.9 or later implementation.

Agent must stop after TASK-1.8.