# TASK-1.12 REVIEW — Quarantine Ambiguous Legacy Clear APIs

## Verdict

Implementation commit reviewed: `92b051fcc2e32193cf3e5b8837784e08b9ad1961`

Production source review: **ACCEPTED**

Final status: **COMPLETED**

Phase 1 status after this review: **COMPLETED**

Build gate: **PASSED — accepted from project-owner continuation**. No GitHub Actions artifact or compiled package is stored in this workspace, so build output was not independently inspected.

## Reviewed scope

The implementation commit contains exactly:

```text
M AppDataCleaner.m
A docs/backup-restore-hardening/reports/TASK-1.12-REPORT.md
```

No protected production file changed.

Independent checks:

```text
git show --check --oneline 92b051f                     PASS
git diff 17d76c0..92b051f --check                     PASS
protected production diff                              PASS
AppDataCleaner.h SHA-256                               unchanged
AppDataCleaner.m NUL bytes                             0
```

## Accepted quarantine contract

The implementation keeps all selector definitions and public declarations while replacing the 33 specified raw-path, raw-UUID, fuzzy-selection and detached-Keychain methods with non-mutating compatibility shims.

Independent parsing confirmed:

```text
quarantined selector definitions       33
logger calls in quarantine bodies      33
logger definitions                      1
combined forbidden-token count          0
PXShellFinalSweep definitions            0
PXShellFinalSweep references             0
```

Every quarantined body:

- casts its arguments unused;
- calls `PXLogQuarantinedLegacyClearSelector(_cmd)` exactly once;
- performs no filesystem inspection or mutation;
- performs no process or shell execution;
- performs no resolver or validator call;
- performs no Keychain operation;
- performs no app lifecycle action;
- performs no fuzzy matching;
- does not redirect to another Clear API;
- does not log raw arguments.

The shared logger accepts only `SEL`, converts it with `NSStringFromSelector` and emits selector identity plus migration guidance. It cannot receive a path, bundle identifier, UUID, entitlement, group identifier or command.

## `securelyWipeFile:` failure semantics

The final body is fail closed:

```objc
- (BOOL)securelyWipeFile:(NSString *)path {
    (void)path;
    PXLogQuarantinedLegacyClearSelector(_cmd);
    return NO;
}
```

It does not inspect path existence and never returns success for an operation that did not occur.

## ABI and compatibility

`AppDataCleaner.h` is byte-identical to the baseline. The 18 public quarantined declarations remain present with unchanged selectors and return types. The 15 private/internal quarantined selectors each retain one implementation definition.

`clearAppData:` and `performSecondaryCleanup:` remain accepted data-only aliases and still delegate exactly once to `completeAppDataWipe:`.

No production caller outside `AppDataCleaner.m` references any of the 33 quarantined selectors. External binaries not represented in the repository may still invoke public selectors; those invocations now intentionally log and do nothing.

## Typed Clear non-regression

Independent baseline-to-commit body extraction confirmed equality for:

```text
PXShellValidatedApplicationDataWipe
PXApplicationDataCommandResultSucceeded
PXApplicationDataPostconditionIsValid
_completeAppDataWipeForApplicationDataRequest:
_completeDataWipeForMigratedRequest:
_clearExactDataContainerComponentForIdentifiers:...
_clearExactAppGroupsComponentForIdentifiers:...
_keychainClearPlanForBundleIdentifier:
_executeKeychainWipeForBundleIdentifier:...
_keychainComponentForPlan:passResults:
clearDataForBundleID:completion:
completeAppDataWipe:
clearAppData:
performSecondaryCleanup:
_wipeMobileSafariSystemStores
```

The following remain unchanged:

- exact four-scope data mask;
- exact five-scope full mask;
- five final component results;
- canonical resolver and validator boundaries;
- strict filesystem postconditions;
- immutable Keychain planning and pass accounting;
- callback failure precedence;
- one-shot completion;
- data-only semantics of `completeAppDataWipe:`.

Legacy cleanup omitted by quarantine is not represented as a false structured success or a new component.

## TASK-1.11 non-regression

Final static inventory:

```text
chmod -R                              0
find ... -exec chmod                  0
chown -R                              0
chflags -R                            1
active shell touch                    0
.nomedia                              0
.initialized                          0
AssistantServices timestamp target    0
Keychain temporary directory 0700     1
Keychain copied helper 0755           1
receipt tokens                        0
PXClearScopeDefaultMask references    0
```

The sole `chflags -R` remains inside the unchanged canonical strict container wipe.

## Report quality

`TASK-1.12-REPORT.md` accurately records:

- baseline and file scope;
- all 33 selectors;
- declaration and definition counts;
- shared logger behavior;
- fail-closed BOOL behavior;
- forbidden-token audit;
- typed body hashes;
- protected checksums;
- external caller inventory;
- 60 static/runtime-pending scenarios;
- whitespace, CRLF and NUL evidence;
- remaining runtime risks.

The report intentionally does not embed the final commit SHA. The coordinator independently tied the report to commit `92b051fcc2e32193cf3e5b8837784e08b9ad1961` and reran the post-commit checks.

## Remaining risks

- External clients outside this repository may depend on legacy public selector side effects. ABI remains intact, but behavior is intentionally non-mutating.
- `_wipeMobileSafariSystemStores` still performs accepted direct fixed-store cleanup while its fuzzy helper calls now no-op.
- Device tests should exercise selector invocation, Objective-C message dispatch and build/link compatibility.
- Phase 2 Restore work must not reintroduce raw manifest paths, UUID fallback or unvalidated archive input.

These risks do not block TASK-1.12 because quarantine, ABI preservation and typed-path non-regression are implemented exactly as specified.
