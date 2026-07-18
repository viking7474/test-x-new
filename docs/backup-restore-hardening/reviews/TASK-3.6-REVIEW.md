# TASK-3.6 Review

Implementation commit reviewed: `c11ac70d2389eb9a9722396336a4ff92826d9e31`

Production source review: **CHANGES_REQUESTED**

Final status: **CHANGES_REQUESTED**

TASK-3.7 may open: **NO**

Corrective task: `TASK-3.6A`

## Scope reviewed

```text
M AppDataBackupManager.m
A PXBackupManifestV4.h
A PXBackupManifestV4.m
M PXBackupManifestValidator.m
A docs/backup-restore-hardening/reports/TASK-3.6-REPORT.md
```

The implementation commit contains only the authorized production files and report. Protected production files are unchanged.

## Accepted architectural work

The implementation correctly establishes most of the intended v4 architecture:

- exact public v4 API with eight exports, fourteen error codes and one immutable `NSCopying` model;
- exact 23-key builder input and 33-key v4 root shape;
- canonical lowercase UUID backup identifier;
- pure in-memory builder with no filesystem or process authority;
- deep immutable graph snapshot with bounded depth, node, dictionary-key, array-item and string limits;
- artifact declarations use `path == name` and never serialize the partial-workspace absolute `filePath`;
- canonical persisted policy strings;
- one required ApplicationData record first;
- nondecreasing artifact-kind order and bounded aggregate size;
- exact declaration/reference coverage;
- v4 excluded Preferences archive is empty;
- factual included/excluded option arrays are builder-derived;
- v2/v3 legacy validation remains isolated;
- unsupported positive versions retain the manager code-201 boundary;
- manager creates one backup UUID, calls the v4 builder once, validates the generated dictionary once and retains the current non-atomic manifest write boundary;
- TASK-3.1 through TASK-3.5 production sources remain unchanged.

## Blocking finding — malformed v4 values may raise Objective-C exceptions

Both new v4 implementations invoke type-specific selectors on values read from caller-controlled dictionaries before proving their runtime classes.

### Validator policy values

`PXManifestV4PolicyMatches(...)` reads untrusted manifest values as `NSString *` and immediately calls `isEqualToString:`:

```objc
NSString *requirement = policy[@"requirement"];
NSString *disposition = policy[@"failureDisposition"];
NSString *empty = policy[@"emptyFilePolicy"];

valid = [requirement isEqualToString:@"required"] &&
        [disposition isEqualToString:@"abortBackup"] &&
        [empty isEqualToString:@"reject"];
```

No runtime `NSString` proof precedes these sends. A manifest containing, for example:

```objc
@"requirement": @1
```

can send `isEqualToString:` to `NSNumber`, causing an `unrecognized selector` exception instead of a validator `NSError`.

### Other validator values

The same fail-open-to-exception pattern appears for:

```text
$.schema.identifier
$.schema.digestAlgorithm
$.publication.protocol
$.publication.contentState
$.backupMode
$.restoreCompatibility.targetBundleID
$.artifacts[*].path
$.archiveChecksum
$.preferences.included
$.keychain.included
$.profileAppData.included
$.globalSafari.included
```

Examples include direct `isEqualToString:` and `boolValue` calls before exact string or exact Boolean validation.

### Builder values

The public v4 builder has the same issue for caller-supplied `fields`:

```text
$.backupMode
$.restoreCompatibility.targetBundleID
$.preferences.included
$.keychain.included
$.profileAppData.included
$.globalSafari.included
```

For example, `BOOL prefsIncluded = [preferences[@"included"] boolValue];` executes before `PXV4ExactBoolean(...)`. An unsupported object such as `NSDictionary` does not implement `boolValue` and can raise an exception rather than returning `PXBackupManifestV4ErrorInvalidFieldValue`.

## Why this blocks acceptance

The manifest validator is a Restore preflight boundary for untrusted on-disk data. Malformed field types must fail closed through the established error contract. An Objective-C exception can terminate or destabilize the application and bypass normal Restore error handling.

The builder is also public production API and must reject malformed input without relying on callers to pre-normalize runtime classes.

Static key-count and valid-fixture tests do not prove this property. The report does not include an exception-based malformed-type matrix covering these selectors.

## Required correction

TASK-3.6A must:

1. modify only `PXBackupManifestV4.m` and `PXBackupManifestValidator.m`;
2. prove every untrusted value has the exact required runtime type before any type-specific selector is sent;
3. read exact Boolean values only after exact CFBoolean validation;
4. compare strings only after runtime `NSString` validation;
5. make malformed policy dictionaries return ordinary validation failure;
6. add an exception harness covering `NSNumber`, `NSDictionary`, `NSArray`, `NSNull`, `NSDate` and `NSData` substitutions at all affected fields;
7. preserve the public v4 header, manager integration, v2/v3 behavior, exact schema, artifact policy, reference coverage and current write boundary.

## Independent static gates

```text
git show --check:                    PASS
baseline-to-HEAD diff --check:       PASS
implementation scope:                PASS
protected production diff:           0
public v4 exports:                    8
v4 error codes:                     14
v4 builder factories:                1
builder filesystem/process calls:    0
absolute artifact-path serialization:0
v4 root-count gate:                  1
v4 validator dispatch:               1
manager v4 factory calls:             1
manager pre-write validator calls:    1
current writeToFile:atomically:       1
final Backup publication operations:  0
report scenario rows:               364
new trailing whitespace:              0
new NUL bytes:                        0
unsafe pre-type selector families:    PRESENT — BLOCKING
```

## Build status

The report records strict frontend and model/static gates. The workspace does not contain a linked Theos/iOS artifact or a runtime malformed-manifest exception fixture that the coordinator can replay independently.

Owner continuation is recorded as build-status context, but it cannot override the directly verified exception-safety defect in the production source.
