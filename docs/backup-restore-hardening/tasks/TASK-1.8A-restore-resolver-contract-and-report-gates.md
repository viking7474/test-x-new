# TASK-1.8A — Restore Resolver Compatibility and Report Gates

- Status: READY
- Parent task: TASK-1.8
- Baseline commit: `45c0360fe225d7e1a835e4715ddbb41576be5b96`
- Required report: `docs/backup-restore-hardening/reports/TASK-1.8A-REPORT.md`
- Next task: TASK-1.9 remains LOCKED

## Purpose

Correct two review blockers without redesigning or extending TASK-1.8:

1. restore the accepted TASK-1.2 identifier-input contract for the public `PXDataContainerResolver` APIs;
2. clean `TASK-1.8-REPORT.md` so cumulative and corrective whitespace gates are truthful and pass.

This is a narrow corrective pass. Do not add behavior, migrate another component or refactor the accepted TASK-1.8 orchestration.

## Required reading

Read before editing:

1. `docs/backup-restore-hardening/reviews/TASK-1.8-REVIEW.md`
2. `docs/backup-restore-hardening/tasks/TASK-1.2-exact-application-data-container-resolver.md`
3. `docs/backup-restore-hardening/tasks/TASK-1.8-migrate-extension-and-pluginkit-data-clear.md`
4. `docs/backup-restore-hardening/reports/TASK-1.8-REPORT.md`
5. `PXDataContainerResolver.h`
6. `PXDataContainerResolver.m`
7. `PXClearRequest.m`
8. the strict installed-extension identifier helper in `AppDataCleaner.m`
9. `docs/backup-restore-hardening/templates/AGENT_REPORT_TEMPLATE.md`

## Allowed changes

Production file allowed:

```text
PXDataContainerResolver.m
```

Agent-owned evidence allowed:

```text
docs/backup-restore-hardening/reports/TASK-1.8-REPORT.md
docs/backup-restore-hardening/reports/TASK-1.8A-REPORT.md
```

Do not modify any other file.

In particular, do not modify:

- `PXDataContainerResolver.h`;
- `AppDataCleaner.h/.m`;
- `PXResolvedContainer.h/.m`;
- `PXDestructivePathValidator.h/.m`;
- `PXClearRequest.h/.m`;
- `PXClearResult.h/.m`;
- `CommandRunner.h/.m`;
- `AppGroupContainerResolver.h/.m`;
- `AppDataBackupManager.h/.m`;
- `Makefile`;
- TASK-1.8 specification;
- coordinator review/status/roadmap/decision files;
- Backup, Restore, UI or Keychain source.

## Correction 1 — Restore TASK-1.2 identifier validation

The resolver identifier validator must use the accepted TASK-1.2 contract.

An identifier is valid when all are true:

1. runtime object is an `NSString`;
2. length is greater than zero;
3. it contains at least one character outside `whitespaceAndNewlineCharacterSet`;
4. it contains no Unicode U+0000.

The resolver must not impose bundle-identifier syntax restrictions.

Do not reject solely because the identifier contains:

- `_`;
- Unicode characters;
- internal whitespace;
- leading/trailing whitespace;
- a leading or trailing dot;
- consecutive dots;
- slash, backslash or wildcard characters.

Those values may be unusual, but TASK-1.2 intentionally defined only runtime/string/nonempty/non-whitespace/no-NUL validation. Exact metadata equality and `PXResolvedContainer` construction remain the later gates.

Do not trim, lowercase, uppercase, normalize or rewrite accepted input.

Recommended helper shape:

```objc
static BOOL PXResolverStringContainsNUL(NSString *value) {
    unichar nulCharacter = 0;
    NSString *nulString =
        [NSString stringWithCharacters:&nulCharacter length:1];
    return [value rangeOfString:nulString].location != NSNotFound;
}

static BOOL PXResolverStringContainsNonWhitespace(NSString *value) {
    NSCharacterSet *whitespace =
        [NSCharacterSet whitespaceAndNewlineCharacterSet];
    return [value rangeOfCharacterFromSet:[whitespace invertedSet]].location
        != NSNotFound;
}

static BOOL PXResolverIdentifierIsValid(id value) {
    if (![value isKindOfClass:[NSString class]]) {
        return NO;
    }

    NSString *identifier = (NSString *)value;
    return identifier.length > 0 &&
           PXResolverStringContainsNonWhitespace(identifier) &&
           !PXResolverStringContainsNUL(identifier);
}
```

The exact helper names may differ, but behavior must match.

Remove the resolver-only strict character helper if it becomes unused:

```text
PXResolverCharacterIsAllowed
```

Do not move or duplicate the strict identifier policy from `AppDataCleaner.m`. The private `.appex` discovery must remain strict because installed extension identifiers are validated using the `PXClearRequest` contract. That code is protected in this corrective task.

## Public API compatibility

Keep the header and both public selectors unchanged:

```objc
- (nullable PXResolvedContainer *)resolveDataContainerForIdentifier:(NSString *)identifier
                                                               kind:(PXResolvedContainerKind)kind
                                                               root:(PXResolvedContainerRoot)root
                                                              error:(NSError * _Nullable * _Nullable)error;

- (nullable PXResolvedContainer *)resolveApplicationDataContainerForIdentifier:(NSString *)identifier
                                                                          root:(PXResolvedContainerRoot)root
                                                                         error:(NSError * _Nullable * _Nullable)error;
```

The existing ApplicationData selector must still delegate to the generic selector using:

```objc
PXResolvedContainerKindApplicationData
```

Do not add overloads, aliases, properties, error codes or new public types.

## Preserve all accepted TASK-1.8 resolver behavior

The correction must not change:

- allowed kinds: ApplicationData, ExtensionData, PluginKitData;
- rejected kind: AppGroup;
- root validation;
- fixed kind/root base mapping;
- no custom base;
- no root/kind fallback;
- rootful canonical spelling;
- base-absent no-error semantics;
- non-directory/enumeration error semantics;
- immediate UUID child enumeration;
- deterministic ordering;
- candidate and metadata symlink rejection already added by TASK-1.8;
- authoritative metadata filename;
- string `MCMMetadataIdentifier` only;
- exact case-sensitive equality;
- zero/one/multiple match semantics;
- `InvalidCandidate` behavior;
- no process, shell or destructive operation.

The generic resolver must continue to contain zero authorization uses of:

```text
hasPrefix:
hasSuffix:
containsString:
lowercaseString
caseInsensitiveCompare:
localizedCaseInsensitiveCompare:
```

## Required validation scenarios

Document static evidence for at least these cases:

| Input | Expected resolver input result |
|---|---|
| dynamic non-string | reject `InvalidInput` |
| empty string | reject `InvalidInput` |
| whitespace-only string | reject `InvalidInput` |
| newline-only string | reject `InvalidInput` |
| embedded U+0000 | reject `InvalidInput` |
| `com.example.app` | accepted for exact resolution |
| `com.example_app` | accepted for exact resolution |
| `café.example` | accepted for exact resolution |
| ` com.example.app ` | accepted unchanged for exact resolution |
| `.com.example` | accepted unchanged for exact resolution |
| `com..example` | accepted unchanged for exact resolution |

Acceptance means the request proceeds to normal exact filesystem resolution. It does not imply a matching container exists.

Also confirm:

- invalid kind remains rejected;
- AppGroup remains rejected;
- invalid root remains rejected;
- existing ApplicationData selector has the same input behavior as the generic selector;
- accepted input is not normalized.

## Correction 2 — Clean TASK-1.8 report

Modify:

```text
docs/backup-restore-hardening/reports/TASK-1.8-REPORT.md
```

Required changes:

1. remove trailing spaces and tabs from every line;
2. update resolver-validation wording so it does not claim strict bundle syntax in the public resolver;
3. explicitly distinguish:
   - permissive TASK-1.2-compatible public resolver input validation;
   - strict `PXClearRequest`-compatible private `.appex` identifier validation;
4. update verification evidence to include the corrective cumulative gate;
5. do not claim a command passed unless its captured result actually passed;
6. preserve the rest of the TASK-1.8 evidence unless correction is needed for factual accuracy.

The report may retain diff excerpts, but all excerpt lines must be trailing-whitespace clean.

## Corrective report

Create:

```text
docs/backup-restore-hardening/reports/TASK-1.8A-REPORT.md
```

It must include:

1. baseline HEAD and initial status;
2. exact files changed;
3. review blockers addressed;
4. before/after resolver input contract;
5. public API compatibility proof;
6. allowed kind/root matrix unchanged;
7. strict `.appex` validation separation proof;
8. scenario matrix above;
9. forbidden-token audit;
10. protected checksum comparison;
11. cumulative TASK-1.8 diff verification;
12. corrective commit diff verification;
13. report whitespace cleanup evidence;
14. full diff/stat for the allowed files;
15. NUL/generated/binary audit;
16. remaining risks.

End with:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

## Protected baseline

Capture SHA-256 before and after for at least:

- `PXDataContainerResolver.h`;
- `AppDataCleaner.h/.m`;
- `PXResolvedContainer.h/.m`;
- `PXDestructivePathValidator.h/.m`;
- `PXClearRequest.h/.m`;
- `PXClearResult.h/.m`;
- `CommandRunner.h/.m`;
- `AppGroupContainerResolver.h/.m`;
- `AppDataBackupManager.h/.m`;
- `Makefile`.

Every protected file must remain unchanged.

## Required verification

Run and record:

```text
git status --short --untracked-files=all
git rev-parse HEAD
git diff --check
git diff --stat -- PXDataContainerResolver.m docs/backup-restore-hardening/reports/TASK-1.8-REPORT.md docs/backup-restore-hardening/reports/TASK-1.8A-REPORT.md
git diff -- PXDataContainerResolver.m docs/backup-restore-hardening/reports/TASK-1.8-REPORT.md docs/backup-restore-hardening/reports/TASK-1.8A-REPORT.md
git diff --exit-code -- <protected files>
```

After committing, also run:

```text
git show --check --oneline HEAD
git diff f98a0f6d9f52cb08f151c29520af6fb6e255616b..HEAD --check
```

Both must pass with no whitespace errors.

Additional source gates:

```text
PXResolverCharacterIsAllowed references: 0
public resolver syntax whitelist: 0
TASK-1.2 non-whitespace check: present
TASK-1.2 U+0000 check: present
generic resolver allowed-kind count: exactly 3
AppGroup accepted by generic resolver: 0
ApplicationData delegation: exactly 1
resolver fuzzy matching tokens: 0
AppDataCleaner.m diff in TASK-1.8A: 0
PXDataContainerResolver.h diff in TASK-1.8A: 0
TASK-1.8-REPORT trailing-whitespace lines: 0
TASK-1.8A-REPORT trailing-whitespace lines: 0
```

## Stop condition

Stop after TASK-1.8A.

Do not:

- start TASK-1.9;
- migrate App Groups;
- alter extension/PluginKit orchestration;
- alter callback precedence;
- change cache behavior;
- change the strict wipe helper;
- change application-bundle discovery;
- change public headers;
- rewrite unrelated report sections;
- perform broad formatting.
