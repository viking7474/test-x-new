# TASK-3.6A — Fix Manifest V4 Malformed-Type Exception Safety

- Status: READY
- Phase: 3 — Atomic Backup Publication
- Baseline: `c11ac70d2389eb9a9722396336a4ff92826d9e31`
- Parent task: TASK-3.6
- Review: `docs/backup-restore-hardening/reviews/TASK-3.6-REVIEW.md`

## Objective

Correct the v4 builder and v4 validator so every malformed caller/on-disk value fails through the established `NSError` contract and no untrusted object receives a type-specific selector before its runtime class is proven.

This is a narrow exception-safety correction. It must not redesign schema v4, manager integration, artifact policy, Restore behavior or manifest publication.

## Authorized scope

Only these production files may change:

```text
PXBackupManifestV4.m
PXBackupManifestValidator.m
```

Create exactly one report:

```text
docs/backup-restore-hardening/reports/TASK-3.6A-REPORT.md
```

The implementation commit may contain only those three paths.

## Protected files

The following must remain byte-identical to baseline:

```text
PXBackupManifestV4.h
PXBackupManifestValidator.h
AppDataBackupManager.h
AppDataBackupManager.m
PXBackupArtifactPolicy.h/.m
PXBackupArtifactWriter.h/.m
PXBackupBundleLock.h/.m
PXBackupPublicationWorkspace.h/.m
PXBackupArtifactVerifier.h/.m
PXBackupArchiveValidator.h/.m
PXRestorePlan.h/.m
all Restore staging/transaction/resolver files
CommandRunner.h/.m
Makefile
UI/controller files
Keychain helper/bridge/script files
```

Do not edit coordinator-owned status, roadmap, decisions, README, task or review files.

## Baseline evidence

Record before editing:

```text
git status --short --untracked-files=all
git rev-parse HEAD
git log -5 --oneline
git diff --check
```

Record SHA-256 before and after for every protected production file.

## Blocking defect

Current code performs unsafe operations on untrusted values before type validation.

Examples:

```objc
BOOL prefsIncluded = [preferences[@"included"] boolValue];

NSString *requirement = policy[@"requirement"];
[requirement isEqualToString:@"required"];

[artifact[@"path"] isEqualToString:artifact[@"name"]];
```

Substituting an object that does not implement `boolValue` or `isEqualToString:` can raise an Objective-C exception instead of returning a builder/validator error.

## Core invariant

For every value originating from:

```text
backupIdentifier
fields
verifiedArtifacts-derived manifest representation
on-disk manifest dictionaries
```

production code must prove the required runtime class before calling any selector whose availability depends on that class.

Required ordering:

```text
runtime type proof
value-format proof
value extraction/comparison
state mutation
```

Forbidden ordering:

```text
boolValue / integerValue / isEqualToString / hasPrefix / UTF-8 conversion
before runtime type proof
```

## Builder correction — `PXBackupManifestV4.m`

### Exact string helpers

Introduce or reuse file-local helpers with semantics equivalent to:

```objc
static BOOL PXV4ReadRequiredString(id value, NSString **outValue);
static BOOL PXV4ReadOptionalString(id value, NSString **outValue);
static BOOL PXV4StringEquals(id value, NSString *expected);
```

Requirements:

- require runtime `NSString`;
- enforce existing NUL/text/UTF-8 limits as appropriate;
- assign output only on success;
- never normalize, trim, lowercase or repair;
- never call string-specific selectors before runtime type proof.

A helper need not use these exact names, but there must be one obvious centralized pattern and zero unsafe direct string-selector sends on caller-controlled values.

### Exact Boolean helper

Introduce or reuse a helper with semantics equivalent to:

```objc
static BOOL PXV4ReadExactBoolean(id value, BOOL *outValue);
```

Requirements:

- require runtime `NSNumber`;
- require exact CFBoolean type;
- call `boolValue` only after both proofs;
- assign output only on success;
- reject integer `@0`/`@1`, strings and custom objects.

### Builder fields requiring explicit proof

At minimum, correct all uses of:

```text
$.backupMode
$.restoreCompatibility.targetBundleID
$.preferences.included
$.keychain.included
$.profileAppData.included
$.globalSafari.included
$.systemGlobalLibrary.included
$.sharedSystemDB.included
$.options.includeAppGroups
$.options.includePreferences
$.options.includeKeychain
```

The last five currently have some short-circuit protection. Keep them protected through an explicit, reviewable exact-Boolean extraction pattern rather than relying on compound-expression ordering.

### Builder string comparisons

The builder must not send `isEqualToString:` to raw values for:

```text
backupMode
restoreCompatibility.targetBundleID
preferences.archive
keychain.archive
keychain.method
profileAppData.archive
globalSafari.archive
```

Validate/extract the strings first, then compare typed local variables.

### Builder error mapping

Malformed field types or values return:

```text
domain: PXBackupManifestV4ErrorDomain
code: PXBackupManifestV4ErrorInvalidFieldValue
```

Use the most stable existing field path possible.

Malformed policy/verified-artifact objects retain their existing artifact/policy codes.

No exception may escape for any malformed-type input covered by this task.

## Validator correction — `PXBackupManifestValidator.m`

### Exact untrusted string helper

Introduce one file-local helper for v4 that safely proves an exact string and optionally compares it:

```objc
static BOOL PXManifestV4ReadString(id value,
                                   BOOL allowEmpty,
                                   NSString **outValue);
```

or an equivalent design.

The helper must:

- require runtime `NSString`;
- enforce existing v4 string/NUL bounds;
- assign only on success;
- avoid type-specific selector sends before proof.

### Exact untrusted Boolean helper

Introduce one helper with semantics equivalent to:

```objc
static BOOL PXManifestV4ReadBoolean(id value, BOOL *outValue);
```

It must require exact CFBoolean before `boolValue`.

Do not weaken the existing legacy v2/v3 Boolean contract.

### Policy dictionary fail-closed behavior

`PXManifestV4PolicyMatches(...)` must independently require all four values to be runtime strings:

```text
kind
requirement
failureDisposition
emptyFilePolicy
```

Then compare exact strings.

For each wrong type, the function returns `NO`; it must never throw.

Size-zero handling remains:

```text
sharedSystemDatabase + allow -> accepted
all reject policies + size 0 -> rejected
```

### Validator fields requiring explicit proof

At minimum, correct all direct type-dependent operations for:

```text
$.schema.identifier
$.schema.digestAlgorithm
$.publication.protocol
$.publication.contentState
$.backupMode
$.restoreCompatibility.targetBundleID
$.artifacts[*].name
$.artifacts[*].path
$.artifacts[*].sha256
$.artifacts[*].policy.kind
$.artifacts[*].policy.requirement
$.artifacts[*].policy.failureDisposition
$.artifacts[*].policy.emptyFilePolicy
$.archiveChecksum
$.preferences.included
$.keychain.included
$.profileAppData.included
$.globalSafari.included
$.systemGlobalLibrary.included
$.sharedSystemDB.included
$.options.includeAppGroups
$.options.includePreferences
$.options.includeKeychain
```

### Typed locals before comparisons

The validator should extract typed locals before compound consistency checks, for example:

```objc
NSString *schemaIdentifier = nil;
if (!PXManifestV4ReadString(schema[@"identifier"], NO, &schemaIdentifier)) {
    return PXManifestFail(...);
}
if (![schemaIdentifier isEqualToString:...]) {
    return PXManifestFail(...);
}
```

For Boolean sections:

```objc
BOOL preferencesIncluded = NO;
if (!PXManifestV4ReadBoolean(preferences[@"included"],
                             &preferencesIncluded)) {
    return PXManifestFail(...);
}
```

Do not rely on left-to-right short-circuit evaluation as the only type-safety proof.

### Validator error contract

For every malformed v4 type:

- return `NO`;
- set a nonnil `PXBackupManifestValidatorErrorDomain` error when an error pointer is supplied;
- use one of the existing six codes;
- do not throw;
- do not return `YES` with a stale error;
- do not expose raw manifest values in descriptions.

Prefer:

```text
InvalidFieldType
InvalidFieldValue
InconsistentField
```

according to existing validator conventions.

### Remove eager placeholder error

The current `PXManifestValidateV4(...)` begins by pre-populating a generic error before validation. Replace this with normal fail-on-demand behavior.

Required public-method contract remains:

```text
entry: clear *error
success: YES + nil error
failure: NO + nonnil error
```

Bare `return NO` branches must be eliminated or routed through a helper that guarantees an error.

## Exception test matrix

Create a temporary harness outside the repository or use the strongest available Objective-C runtime test.

For each affected field, substitute at least:

```text
NSNumber
NSDictionary
NSArray
NSNull
NSDate
NSData
```

Where the expected type is Boolean, also test:

```text
integer @0
integer @1
string "true"
string "false"
```

Where the expected type is string, also test:

```text
empty string when nonempty is required
embedded NUL
non-lossless UTF-8 fixture where representable by the harness
```

Required harness behavior:

```text
@try validation/build call
@catch -> test failure
ordinary nil/NO + NSError -> PASS
```

Minimum explicit malformed-type cases:

```text
builder:   60
validator: 120
```

No temporary harness, stub or generated fixture may be committed.

## Static selector-safety gates

After correction, direct raw-value patterns in the v4 implementations must be zero.

Examples of forbidden patterns:

```text
[<dictionary subscript> boolValue]
[<dictionary subscript> isEqualToString:]
NSString *x = policy[...] followed by isEqualToString without class proof
BOOL x = [section[...] boolValue] before exact Boolean proof
```

Required counts:

```text
builder exact-Boolean helper definitions:     1
validator exact-Boolean helper definitions:   1
validator policy string-class gate:            1
builder unsafe raw boolValue sites:             0
validator unsafe raw boolValue sites:           0
builder unsafe raw isEqualToString sites:       0
validator unsafe raw isEqualToString sites:     0
validator eager placeholder-error block:        0
validator success returns with nil error:        1 or more explicit paths
bare v4 validator return-NO without error:       0
```

Comparisons on typed local variables are allowed.

## Preserve TASK-3.6 schema

Do not change:

```text
v4 public exports
fourteen v4 error codes
23 input keys
33 root keys
schema identifier/revision/digest
publication protocol/content state
backup UUID contract
artifact declaration keys
path == name
policy string values
artifact order
one required ApplicationData first
aggregate count/size/checksum
exact declaration/reference coverage
v4 excluded Preferences empty archive
factual included/excluded arrays
v2/v3 legacy behavior
unknown positive version behavior
manager-supported versions 2/3/4
manager code 107 fallback
current writeToFile:atomically:
```

## Non-regression

Required byte-identical files include:

```text
PXBackupManifestV4.h
PXBackupManifestValidator.h
AppDataBackupManager.m
all TASK-3.1 through TASK-3.5 source
all Restore source
UI/controller source
Makefile
Keychain helper/bridge/script source
```

Do not implement:

```text
TASK-3.7 atomic manifest writing
manifest fsync/read-back/renameat
TASK-3.8 final Backup publication
TASK-3.9 centralized cleanup
TASK-3.10 stale partial cleanup
Phase 4, 5 or 6 work
```

## Build and source proof

Run strongest available gates:

```text
strict Objective-C frontend
-Werror=implicit-function-declaration
-Wall/-Wextra where available
runtime exception harness
validator success/failure error contract harness
```

If full Theos/iOS link is unavailable, state that honestly and include temporary-harness commands/results without committing harness files.

## Report

Create:

```text
docs/backup-restore-hardening/reports/TASK-3.6A-REPORT.md
```

The report must include:

1. baseline and exact scope;
2. protected SHA-256 before/after;
3. TASK-3.6 blocker explanation;
4. complete unsafe-selector inventory before correction;
5. builder typed-string extraction;
6. builder exact-Boolean extraction;
7. validator typed-string extraction;
8. validator exact-Boolean extraction;
9. policy dictionary runtime-type proof;
10. schema/publication type proof;
11. artifact path/checksum type proof;
12. component inclusion type proof;
13. removal of eager placeholder error;
14. no bare-failure-without-error proof;
15. exception harness matrix and results;
16. success/error contract results;
17. valid v4 fixture non-regression;
18. malformed v4 fixture fail-closed results;
19. v2/v3/unknown-version non-regression;
20. public header and manager byte identity;
21. TASK-3.1 through TASK-3.5 byte identity;
22. exact authorized diff;
23. static gate table;
24. at least 180 explicit scenario rows;
25. whitespace/CRLF/NUL audit;
26. build status and remaining runtime risks.

End exactly:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

## Post-commit gates

```text
git show --check --oneline HEAD
git show --stat --oneline HEAD
git diff c11ac70d2389eb9a9722396336a4ff92826d9e31..HEAD --check
git diff --name-status c11ac70d2389eb9a9722396336a4ff92826d9e31..HEAD
git status --short --untracked-files=all
```

Suggested commit:

```text
phase3(task-3.6A): make manifest v4 type validation exception safe
```

Stop after TASK-3.6A. Do not begin TASK-3.7 or any later task.
