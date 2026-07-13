# TASK-1.8A Review

## Verdict

```text
Task: TASK-1.8A — Restore Resolver Compatibility and Report Gates
Commit reviewed: 6f74381ea0cf1e7172ff399bc0fac511ac358089
Build gate: PASSED — reported by project owner
Review status: ACCEPTED
Parent TASK-1.8 status after correction: ACCEPTED
Next task: TASK-1.9 may be opened by the coordinator
```

## Scope reviewed

Corrective production change:

- `PXDataContainerResolver.m`

Corrective evidence:

- `docs/backup-restore-hardening/reports/TASK-1.8-REPORT.md`
- `docs/backup-restore-hardening/reports/TASK-1.8A-REPORT.md`
- `docs/backup-restore-hardening/tasks/TASK-1.8A-restore-resolver-contract-and-report-gates.md`

Protected corrective files included `PXDataContainerResolver.h`, `AppDataCleaner.h/.m`, the resolved-container/request/result/validator models, command runner, App Group resolver, backup manager and Makefile.

## Accepted corrections

1. The public resolver identifier boundary again requires only runtime `NSString`, nonempty, at least one non-whitespace/non-newline character and no U+0000.
2. Accepted identifiers are not trimmed, normalized, lowercased, uppercased or rewritten.
3. The resolver no longer contains an ASCII bundle-identifier whitelist.
4. Values such as underscore-bearing, Unicode, surrounding-space, leading-dot and consecutive-dot strings proceed to exact metadata resolution rather than failing input validation.
5. The generic resolver still accepts exactly ApplicationData, ExtensionData and PluginKitData.
6. AppGroup and invalid kinds remain rejected.
7. Fixed root mapping, exact metadata equality, deterministic enumeration, symlink rejection and ambiguity failure remain unchanged.
8. The legacy ApplicationData selector still delegates exactly once to the generic resolver with `PXResolvedContainerKindApplicationData`.
9. Strict PXClearRequest-equivalent identifier validation remains private to installed `.appex` discovery in `AppDataCleaner.m`.
10. `AppDataCleaner.m` and `PXDataContainerResolver.h` have zero corrective diff.
11. `TASK-1.8-REPORT.md` and `TASK-1.8A-REPORT.md` contain no trailing whitespace or NUL bytes.
12. No temporary generator, binary or build artifact was committed.

## Independent verification

The following gates passed during coordinator review:

```text
git show --check --oneline 6f74381
git diff f98a0f6d9f52cb08f151c29520af6fb6e255616b..6f74381 --check
```

Corrective commit scope is exactly:

```text
PXDataContainerResolver.m
docs/backup-restore-hardening/reports/TASK-1.8-REPORT.md
docs/backup-restore-hardening/reports/TASK-1.8A-REPORT.md
```

Protected corrective diff returned exit code `0`.

Static source gates:

```text
PXResolverCharacterIsAllowed references: 0
resolver fuzzy matching tokens: 0
resolver normalization tokens: 0
AppGroup accepted by generic resolver: 0
ApplicationData delegation: 1
TASK-1.8-REPORT trailing whitespace: 0
TASK-1.8A-REPORT trailing whitespace: 0
```

## Parent TASK-1.8 conclusion

The two blockers recorded in `TASK-1.8-REVIEW.md` are resolved without changing the accepted ExtensionData/PluginKitData migration. The parent implementation retains:

- exact installed `.appex` identity;
- generic exact container resolution;
- canonical validator output as the only migrated mutation target;
- one bounded command per resolved container;
- post-command revalidation and strict postconditions;
- exact component accounting;
- three-scope aggregate and deterministic callback failure precedence;
- separate canonical ExtensionData and PluginKitData caches;
- application-bundle read-only behavior.

TASK-1.8 and TASK-1.8A are accepted. TASK-1.9 may now migrate App Group clear through its dedicated exact resolver and structured component boundary.
