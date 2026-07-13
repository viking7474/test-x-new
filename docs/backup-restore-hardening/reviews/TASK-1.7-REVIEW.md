# TASK-1.7 Review — Migrate Main Application-Data Clear

## Decision

**ACCEPTED**

TASK-1.7 is accepted after source, commit, contract and safety-boundary review.

Reviewed commit:

```text
f98a0f6d9f52cb08f151c29520af6fb6e255616b — task 1.7
```

Build gate:

```text
PASSED — reported by project owner
```

## Reviewed artifacts

- `AppDataCleaner.m`
- `docs/backup-restore-hardening/reports/TASK-1.7-REPORT.md`
- complete commit diff from `81de2a7` to `f98a0f6`

## Accepted findings

### Exact target selection

The migrated main application-data path resolves rootful and rootless containers only through `PXDataContainerResolver` using exact metadata identity.

Inside the private migrated method there are zero calls to:

- `findDataContainerUUID:`;
- `findRootlessDataContainerUUID:`;
- optimized fuzzy data UUID finders;
- content, company-name or short-name matching.

### Canonical destructive boundary

Every resolved root is validated before mutation by `PXDestructivePathValidator`.

The wipe command receives only the canonical path returned by the validator. The migrated path does not use `container.containerPath`, `container.containerUUID`, reconstructed `/var/mobile` paths or `completelyWipeContainer:`.

### Independent root units

Rootful and rootless are processed in deterministic order and independently.

- absent root without resolver error is not attempted;
- resolver/validation/execution/revalidation/postcondition failure is one failed attempted unit;
- one root failure does not prevent the other root from running;
- partial success is represented by `Failed` with mixed unit counts.

### Strict execution and postcondition

The main wipe uses the bounded result-returning command API once per validated root.

Required remove and directory-creation operations affect an explicit status accumulator. `CommandResult` failure and output truncation fail closed.

After command success, the same resolved container is validated again, canonical identity must remain unchanged and the filesystem postcondition requires only the two metadata entries plus empty real `Documents`, `Library` and `tmp` directories.

### Structured result and completion propagation

The migrated operation returns one `PXClearComponentResult` for `PXClearScopeApplicationData`.

Legacy completion behavior now propagates ApplicationData failure. If ApplicationData and Keychain both fail, ApplicationData has callback-error precedence while the Keychain failure is logged.

### Cache migration

Raw main-container UUID cache fields were removed. Main verification consumes copied canonical paths directly.

The canonical cache may include a validated path whose later command or postcondition failed. This is acceptable because subsequent uses are read-only verification only, and the unit has already been classified as failed; the cache cannot convert it into a successful unit.

### Scope preservation

TASK-1.7 does not migrate ExtensionData, PluginKitData, AppGroups or Keychain result modeling.

Application-bundle read-only gates remain intact:

- `_MASReceipt`: 0;
- `._MASReceipt`: 0;
- rootless application-bundle full wipe: absent.

## Non-blocking remaining risks

1. Legacy public and private helpers outside the migrated main flow can still perform fuzzy/raw main-container mutation. They remain for later quarantine work.
2. Extension and PluginKit discovery still uses prefix-based metadata matching and raw UUID paths in the legacy main flow.
3. The strict shell remains path-based and cannot eliminate every privileged filesystem race between individual shell operations.
4. The postcondition can fail if a system service recreates data while the app is frozen; this is intentionally fail-closed.
5. Local iOS runtime testing was unavailable in the review workspace.

## Verification summary

```text
required imports: 4
legacy main resolver calls in migrated method: 0
raw main path reconstruction in migrated method: 0
raw container-property mutation: 0
generic completelyWipeContainer main call: 0
bounded result command call inside root loop: 1
validator call sites: 2
old main UUID cache fields: 0
canonical main cache references: 5
receipt tokens: 0
protected production diff outside AppDataCleaner.m: 0
git show --check f98a0f6: PASS
git diff --check: PASS
newly added trailing-whitespace lines: 0
```

## Gate result

TASK-1.7 is **COMPLETED**.

TASK-1.8 may open for exact ExtensionData and PluginKitData migration.