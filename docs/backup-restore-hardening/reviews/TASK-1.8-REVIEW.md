# TASK-1.8 Review

## Verdict

```text
Task: TASK-1.8
Commit reviewed: 45c0360fe225d7e1a835e4715ddbb41576be5b96
Build gate: PASSED — reported by project owner
Production source review: CHANGES_REQUESTED
Final status: NOT COMPLETED
Next gate: TASK-1.8A corrective pass
TASK-1.9: LOCKED
```

TASK-1.8 is not accepted yet. The ExtensionData/PluginKitData migration is substantially correct, but the commit changes the accepted public resolver input contract and the committed report fails the whitespace gate.

## Scope reviewed

Production changes:

- `PXDataContainerResolver.h`
- `PXDataContainerResolver.m`
- `AppDataCleaner.m`

Task evidence:

- `docs/backup-restore-hardening/reports/TASK-1.8-REPORT.md`
- `docs/backup-restore-hardening/tasks/TASK-1.8-migrate-extension-and-pluginkit-data-clear.md`

## Accepted implementation areas

Static review accepted the following portions:

1. The generic resolver API shape is correct and the existing ApplicationData selector delegates to it.
2. Kind/root mapping is fixed for ApplicationData, ExtensionData and PluginKitData; AppGroup is rejected.
3. Container selection remains exact and case-sensitive through `MCMMetadataIdentifier`.
4. Installed extension identity is derived from real contained `.appex` bundles rather than parent identifier prefixes.
5. Rootful/rootless and identifier processing order is deterministic.
6. ExtensionData and PluginKitData use exact resolver output, canonical validator output, one bounded command per container, post-command validation and strict postconditions.
7. The internal aggregate contains exactly ApplicationData, ExtensionData and PluginKitData.
8. Callback failure precedence is ApplicationData, ExtensionData, PluginKitData, then Keychain.
9. Raw extension dictionaries were removed from the migrated main path and replaced by separate canonical path caches.
10. The migrated main path no longer invokes legacy extension discovery/mutation or global `clearPluginKitData:`.
11. App Group and Keychain component migration remain out of scope.
12. Application-bundle receipt/write gates remain intact.
13. Protected production files outside the three allowed sources are unchanged.

## Blocking finding 1 — public resolver input contract regression

TASK-1.8 requires preserving the TASK-1.2 resolver rules. TASK-1.2 accepts an identifier when it:

- is an `NSString` at runtime;
- is nonempty;
- contains at least one non-whitespace/non-newline character;
- contains no U+0000;
- is retained exactly without trimming, lowercasing or normalization.

TASK-1.2 deliberately does not impose bundle-identifier syntax restrictions.

The TASK-1.8 implementation replaced that accepted contract with an ASCII bundle-identifier validator:

```objc
static BOOL PXResolverCharacterIsAllowed(unichar character) { ... }
```

and rejects values with:

- underscores;
- Unicode characters;
- internal or surrounding spaces;
- other strings that are valid under the accepted TASK-1.2 contract.

Because `resolveApplicationDataContainerForIdentifier:root:error:` now delegates to the generic method, this is a behavior regression in the existing public API, not only a new-method policy.

Required correction:

- restore the original TASK-1.2 identifier validation in `PXDataContainerResolver.m`;
- keep strict `PXClearRequest`-equivalent validation only in the private installed `.appex` discovery path in `AppDataCleaner.m`;
- do not change exact equality, kind/root mapping, symlink hardening or ambiguity behavior.

## Blocking finding 2 — committed report fails whitespace verification

The report states:

```text
git diff --check: pass
```

However:

```text
git show --check 45c0360
```

reports trailing whitespace in many added lines of:

```text
docs/backup-restore-hardening/reports/TASK-1.8-REPORT.md
```

The production files do not appear in the `git show --check` failures; the issue is confined to the report. The report must be cleaned and its verification section corrected so cumulative TASK-1.8 evidence is truthful.

## Non-blocking observations

- The commit includes coordinator-owned TASK-1.8 specification/review/status artifacts together with implementation. This is expected from the working-tree baseline but weakens one-task/one-commit traceability.
- `origin/newok` was still at TASK-1.7 during review. Push status is operational, not a source acceptance gate.
- The report baseline subject differs from the actual short commit subject; the baseline SHA is correct.

## Required corrective gate

TASK-1.8 remains `CHANGES_REQUESTED` until TASK-1.8A demonstrates:

1. TASK-1.2-compatible resolver identifier validation is restored.
2. The generic resolver still supports exactly ApplicationData, ExtensionData and PluginKitData.
3. AppGroup remains rejected.
4. Existing ApplicationData API delegation remains intact.
5. Strict `.appex` identifier validation remains in `AppDataCleaner.m` and is not moved into the public resolver.
6. No other TASK-1.8 production behavior changes.
7. `git diff f98a0f6..HEAD --check` passes.
8. `git show --check <corrective-commit>` passes.
9. `TASK-1.8-REPORT.md` contains no trailing whitespace and no false whitespace-pass claim.
10. GitHub Actions succeeds for the corrective commit.

TASK-1.9 must not begin before this corrective review is accepted.

## Corrective follow-up

TASK-1.8A was completed in commit:

```text
6f74381ea0cf1e7172ff399bc0fac511ac358089
```

The corrective review accepted all required gates:

- TASK-1.2-compatible public resolver input validation was restored;
- strict `.appex` identifier validation remained isolated in `AppDataCleaner.m`;
- generic resolver kind/root, exact metadata and ambiguity behavior did not change;
- `AppDataCleaner.m` and the public resolver header had zero corrective diff;
- the TASK-1.8 and TASK-1.8A reports are whitespace-clean;
- corrective and cumulative `--check` gates passed;
- the project owner reported the build gate passed.

Final parent verdict:

```text
TASK-1.8: COMPLETED
Review status: ACCEPTED after TASK-1.8A
Accepted implementation commit: 45c0360fe225d7e1a835e4715ddbb41576be5b96
Accepted corrective commit: 6f74381ea0cf1e7172ff399bc0fac511ac358089
TASK-1.9: eligible to open
```
